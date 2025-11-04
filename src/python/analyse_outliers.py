#!/usr/bin/env python3

"""
EvoNEST Outlier Analysis Script
Analyzes experimental data for outliers using sigma-based detection
Performs hierarchical analysis grouping by Family > Species > Subsample Type
Manages configuration in config/analyse_outliers_config.json
"""

import json
from pathlib import Path
from typing import Dict

import numpy as np
import pandas as pd
from tqdm import tqdm


class ConfigManager:
    """Manages persistent configuration for outlier analysis"""
    
    CONFIG_DIR = Path(__file__).parent.parent / "config"
    CONFIG_FILE = CONFIG_DIR / "analyse_outliers_config.json"
    
    DEFAULT_CONFIG = {
        "analysis": {
            "outlier_trait_threshold": 0.3,  # 30% of traits must be outliers to flag experiment
            "sigma_level": 2  # 1, 2, or 3
        },
        "output": {
            "output_dir": "processed_data",
            "analysis_file": "outlier_analysis.json",
            "experiments_file": "outlier_experiments.csv"
        }
    }
    
    def __init__(self):
        """Initialize config manager"""
        self.config_dir = self.CONFIG_DIR
        self.config_file = self.CONFIG_FILE
        self.config = self.load_config()
    
    def load_config(self):
        """Load configuration from file or create default"""
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    saved_config = json.load(f)
                # Merge with defaults
                config = self._merge_configs(self.DEFAULT_CONFIG.copy(), saved_config)
                return config
            except (json.JSONDecodeError, IOError):
                print("⚠️  Warning: Could not read config file, using defaults")
                return self.DEFAULT_CONFIG.copy()
        else:
            return self.DEFAULT_CONFIG.copy()
    
    def save_config(self):
        """Save configuration to file"""
        try:
            self.config_dir.mkdir(parents=True, exist_ok=True)
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2)
            print(f"✅ Configuration saved to {self.config_file}")
            return True
        except IOError as e:
            print(f"⚠️  Warning: Could not save config: {e}")
            return False
    
    def _merge_configs(self, default, saved):
        """Recursively merge saved config with defaults"""
        result = default.copy()
        for key, value in saved.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self._merge_configs(result[key], value)
            else:
                result[key] = value
        return result


class OutlierAnalyzer:
    """Analyze experimental data for outliers using sigma-based detection"""
    
    def __init__(self, input_file='processed_data/hierarchical_experiment_data_no_curves.json', config_manager=None):
        """
        Args:
            input_file: Path to hierarchical_experiment_data_no_curves.json
            config_manager: ConfigManager instance (uses default if None)
        """
        self.input_file = input_file
        self.config_mgr = config_manager or ConfigManager()
        self.config = self.config_mgr.config
        
        self.outlier_trait_threshold = self.config['analysis']['outlier_trait_threshold']
        self.sigma_level = self.config['analysis']['sigma_level']
        self.output_dir = self.config['output']['output_dir']
        
        self.data = None
        self.experiments_df = None
        
    def load_data(self):
        """Load the processed experimental data"""
        input_path = Path(__file__).parent.parent / self.input_file
        
        with open(input_path, 'r', encoding='utf-8') as f:
            self.data = json.load(f)
        
        print(f"Loaded {self.data['metadata']['total_experiments']} experiments")
        print(f"Polynomial degree: {self.data['metadata']['polynomial_degree']}")
        
    def prepare_dataframe(self):
        """Convert experiments to pandas DataFrame for analysis"""
        records = []
        
        for exp_id, exp_data in self.data['experiments'].items():
            # Start with experiment ID and basic info
            record = {
                'experiment_id': exp_id,
                'sample_name': exp_data.get('sample_name'),
                'family': exp_data.get('family'),
                'genus': exp_data.get('genus'),
                'species': exp_data.get('species'),
                'name': exp_data.get('genus') + ' ' + exp_data.get('species') if exp_data.get('genus') and exp_data.get('species') else '',
                'subsampletype': exp_data.get('subsampletype'),
                'type': exp_data.get('type'),
            }
            
            # Add polynomial coefficients as separate columns
            poly_coeffs = exp_data.get('polynomial_coefficients', [])
            for i, coeff in enumerate(poly_coeffs):
                record[f'coeff_{i}'] = coeff
            
            # Add fit quality metric
            record['r_squared'] = exp_data.get('r_squared')
            
            # Extract traits by type - aggregate multiple measurements of same type
            traits_dict = {}  # trait_type -> list of measurements
            traits = exp_data.get('associatedTraits', [])
            for trait in traits:
                trait_type = trait.get('type')
                measurement = trait.get('measurement')
                
                if trait_type and measurement is not None:
                    # Convert measurement to numeric
                    try:
                        numeric_val = float(measurement)
                    except (ValueError, TypeError):
                        numeric_val = np.nan
                    
                    # Collect all measurements for this trait type
                    if trait_type not in traits_dict:
                        traits_dict[trait_type] = []
                    traits_dict[trait_type].append(numeric_val)
            
            # Store aggregated traits (take mean if multiple measurements)
            for trait_type, measurements in traits_dict.items():
                # Filter out NaN values
                valid_measurements = [m for m in measurements if not np.isnan(m)]
                
                if valid_measurements:
                    col_name = f"trait_{trait_type}"
                    # Take the mean of multiple measurements, or single value if only one
                    record[col_name] = np.mean(valid_measurements)
                else:
                    col_name = f"trait_{trait_type}"
                    record[col_name] = np.nan
            
            records.append(record)
        
        self.experiments_df = pd.DataFrame(records)
        
        # Convert all trait columns to numeric
        trait_columns = [col for col in self.experiments_df.columns if col.startswith('trait_')]
        for col in trait_columns:
            self.experiments_df[col] = pd.to_numeric(self.experiments_df[col], errors='coerce')
        
        print(f"\nDataFrame created with {len(self.experiments_df)} experiments")
        print(f"Columns: {list(self.experiments_df.columns)}")
        
    def calculate_statistics_for_group(self, group_df: pd.DataFrame, column: str) -> Dict:
        """Calculate mean, std, and sigma thresholds for a numeric column within a group"""
        values = group_df[column].dropna()
        
        if len(values) == 0:
            return None
        
        try:
            mean = values.mean()
            std = values.std()
        except Exception as e:
            print(f"⚠️  Warning: Could not compute statistics for column '{column}': {e}")
            return None
        
        return {
            'column': column,
            'count': len(values),
            'mean': mean,
            'std': std,
            'min': values.min(),
            'max': values.max(),
            'median': values.median(),
            'sigma_1_low': mean - std,
            'sigma_1_high': mean + std,
            'sigma_2_low': mean - 2*std,
            'sigma_2_high': mean + 2*std,
            'sigma_3_low': mean - 3*std,
            'sigma_3_high': mean + 3*std,
        }
    
    def find_outliers_in_group(self, group_df: pd.DataFrame, column: str, stats: Dict, sigma_level: int = 1) -> pd.DataFrame:
        """Find outliers within a group beyond sigma_level standard deviations"""
        if stats is None:
            return pd.DataFrame()
        
        low_threshold = stats[f'sigma_{sigma_level}_low']
        high_threshold = stats[f'sigma_{sigma_level}_high']
        
        outliers = group_df[
            (group_df[column].notna()) &
            ((group_df[column] < low_threshold) | 
             (group_df[column] > high_threshold))
        ].copy()
        
        if len(outliers) == 0:
            return pd.DataFrame()
        
        outliers['value'] = outliers[column]
        outliers['deviation'] = (outliers[column] - stats['mean']) / stats['std']
        outliers['abs_deviation'] = outliers['deviation'].abs()
        outliers = outliers.sort_values('abs_deviation', ascending=False)
        
        return outliers[['experiment_id', 'sample_name', 'family', 'name', 'subsampletype', 'value', 'deviation']]
    
    def identify_outlier_experiments(self, results: Dict, sigma_level: int = 2) -> pd.DataFrame:
        """
        Identify experiments that have a high percentage of outlier traits
        
        Args:
            results: Analysis results from analyze_all_traits()
            sigma_level: Which sigma level to use (1, 2, or 3)
        
        Returns:
            DataFrame with outlier experiments and their outlier trait percentages
        """
        outlier_experiments = []
        
        for group_key, group_data in results.items():
            family = group_data['family']
            name = group_data['name']
            subsampletype = group_data['subsampletype']
            
            # Track which experiments are outliers in how many traits
            experiment_outlier_count = {}
            total_traits = len(group_data['traits'])
            
            if total_traits == 0:
                continue
            
            for trait, analysis in group_data['traits'].items():
                outliers = analysis[f'outliers_{sigma_level}sigma']
                
                for _, row in outliers.iterrows():
                    exp_id = row['experiment_id']
                    if exp_id not in experiment_outlier_count:
                        experiment_outlier_count[exp_id] = {
                            'count': 0,
                            'sample_name': row['sample_name'],
                            'family': family,
                            'name': name,
                            'subsampletype': subsampletype,
                            'outlier_trait_list': []
                        }
                    experiment_outlier_count[exp_id]['count'] += 1
                    experiment_outlier_count[exp_id]['outlier_trait_list'].append(trait)
            
            # Check which experiments exceed the threshold
            for exp_id, data in experiment_outlier_count.items():
                outlier_percentage = data['count'] / total_traits
                
                if outlier_percentage >= self.outlier_trait_threshold:
                    outlier_experiments.append({
                        'experiment_id': exp_id,
                        'sample_name': data['sample_name'],
                        'family': data['family'],
                        'name': data['name'],
                        'subsampletype': data['subsampletype'],
                        'outlier_traits': data['count'],
                        'total_traits': total_traits,
                        'outlier_percentage': outlier_percentage,
                        'sigma_level': sigma_level,
                        'outlier_trait_list': ', '.join(data['outlier_trait_list'])
                    })
        
        outlier_df = pd.DataFrame(outlier_experiments)
        if len(outlier_df) > 0:
            outlier_df = outlier_df.sort_values('outlier_percentage', ascending=False)
        
        return outlier_df
    
    def analyze_all_traits(self) -> Dict:
        """Analyze all numerical traits for outliers hierarchically by family > name > subsampletype"""
        # Automatically find all columns to analyze
        traits_to_analyze = []
        
        # Add r_squared (fit quality)
        if 'r_squared' in self.experiments_df.columns:
            traits_to_analyze.append('r_squared')
        
        # Add polynomial coefficients
        poly_degree = self.data['metadata']['polynomial_degree']
        for i in range(poly_degree + 1):
            col_name = f'coeff_{i}'
            if col_name in self.experiments_df.columns:
                traits_to_analyze.append(col_name)
        
        # Add all trait_ columns (extracted from traits array)
        trait_columns = [col for col in self.experiments_df.columns if col.startswith('trait_')]
        traits_to_analyze.extend(trait_columns)
        
        results = {}
        
        print("\n" + "="*80)
        print("HIERARCHICAL STATISTICAL ANALYSIS OF TENSILE TEST DATA")
        print("="*80)
        print(f"Analyzing {len(traits_to_analyze)} traits: polynomial coefficients and measurements")
        print("Grouping by: Family > Species (name) > Subsample Type")
        
        # Group by family, name, subsampletype
        grouped = self.experiments_df.groupby(['family', 'name', 'subsampletype'], dropna=False)
        
        # Create list of groups for progress bar
        groups_list = list(grouped)
        
        for (family, name, subsampletype), group_df in tqdm(groups_list, desc="Analyzing groups", unit="group"):
            group_key = f"{family}_{name}_{subsampletype}"
            
            if len(group_df) < 2:  # Need at least 2 samples for statistics
                continue
            
            results[group_key] = {
                'family': family,
                'name': name,
                'subsampletype': subsampletype,
                'sample_count': len(group_df),
                'traits': {}
            }
            
            for trait in traits_to_analyze:
                if trait not in group_df.columns:
                    continue
                
                stats = self.calculate_statistics_for_group(group_df, trait)
                if stats is None or stats['count'] < 2:
                    continue
                
                results[group_key]['traits'][trait] = {
                    'statistics': stats,
                    'outliers_1sigma': self.find_outliers_in_group(group_df, trait, stats, sigma_level=1),
                    'outliers_2sigma': self.find_outliers_in_group(group_df, trait, stats, sigma_level=2),
                    'outliers_3sigma': self.find_outliers_in_group(group_df, trait, stats, sigma_level=3),
                }
        
        return results
    
    def print_analysis_report(self, results: Dict):
        """Print a summary of the analysis (detailed group output removed for cleaner display)"""
        
        # Just count statistics without verbose output
        total_groups = len(results)
        groups_with_1sigma = sum(1 for group_data in results.values() 
                                 if any(len(trait['outliers_1sigma']) > 0 for trait in group_data['traits'].values()))
        groups_with_2sigma = sum(1 for group_data in results.values() 
                                 if any(len(trait['outliers_2sigma']) > 0 for trait in group_data['traits'].values()))
        groups_with_3sigma = sum(1 for group_data in results.values() 
                                 if any(len(trait['outliers_3sigma']) > 0 for trait in group_data['traits'].values()))
        
        print(f"\n{'='*80}")
        print("ANALYSIS COMPLETE")
        print(f"{'='*80}")
        print(f"Analyzed {total_groups} groups (Family > Species > Subsample Type)")
        print(f"Groups with 1σ outliers: {groups_with_1sigma}/{total_groups}")
        print(f"Groups with 2σ outliers: {groups_with_2sigma}/{total_groups}")
        print(f"Groups with 3σ outliers: {groups_with_3sigma}/{total_groups}")
    
    def save_outlier_report(self, results: Dict):
        """Save hierarchical outlier analysis to JSON file"""
        output_data = {
            'metadata': {
                'analysis_date': pd.Timestamp.now().isoformat(),
                'source_file': str(self.input_file),
                'total_experiments': len(self.experiments_df),
                'polynomial_degree': self.data['metadata']['polynomial_degree'],
                'grouping': 'family > name > subsampletype',
                'total_groups': len(results),
                'outlier_trait_threshold': self.outlier_trait_threshold,
                'sigma_level': self.sigma_level
            },
            'groups': {}
        }
        
        for group_key, group_data in results.items():
            family = group_data['family']
            name = group_data['name']
            subsampletype = group_data['subsampletype']
            
            # Convert trait analyses to JSON-serializable format
            traits_output = {}
            for trait, analysis in group_data['traits'].items():
                stats = analysis['statistics']
                
                outliers_1sigma = analysis['outliers_1sigma'].to_dict('records') if len(analysis['outliers_1sigma']) > 0 else []
                outliers_2sigma = analysis['outliers_2sigma'].to_dict('records') if len(analysis['outliers_2sigma']) > 0 else []
                outliers_3sigma = analysis['outliers_3sigma'].to_dict('records') if len(analysis['outliers_3sigma']) > 0 else []
                
                traits_output[trait] = {
                    'statistics': {
                        'count': int(stats['count']),
                        'mean': float(stats['mean']),
                        'std': float(stats['std']),
                        'min': float(stats['min']),
                        'max': float(stats['max']),
                        'median': float(stats['median']),
                        'sigma_ranges': {
                            '1sigma': [float(stats['sigma_1_low']), float(stats['sigma_1_high'])],
                            '2sigma': [float(stats['sigma_2_low']), float(stats['sigma_2_high'])],
                            '3sigma': [float(stats['sigma_3_low']), float(stats['sigma_3_high'])],
                        }
                    },
                    'outliers': {
                        '1sigma': outliers_1sigma,
                        '2sigma': outliers_2sigma,
                        '3sigma': outliers_3sigma,
                    }
                }
            
            output_data['groups'][group_key] = {
                'family': family if pd.notna(family) else None,
                'name': name if pd.notna(name) else None,
                'subsampletype': subsampletype if pd.notna(subsampletype) else None,
                'sample_count': group_data['sample_count'],
                'traits': traits_output
            }
        
        output_path = Path(__file__).parent.parent / self.output_dir
        output_path.mkdir(parents=True, exist_ok=True)
        
        analysis_file = output_path / self.config['output']['analysis_file']
        
        with open(analysis_file, 'w') as f:
            json.dump(output_data, f, indent=2)
        
        print(f"\n{'='*80}")
        print(f"Outlier analysis saved to: {analysis_file}")
        print(f"{'='*80}")
    
    def run_analysis(self):
        """Run complete outlier analysis"""
        self.load_data()
        self.prepare_dataframe()
        results = self.analyze_all_traits()
        self.print_analysis_report(results)
        
        # Identify outlier experiments
        print(f"\n{'='*80}")
        print(f"OUTLIER EXPERIMENTS (≥{self.outlier_trait_threshold*100:.0f}% traits beyond {self.sigma_level}σ)")
        print(f"{'='*80}")
        
        outlier_exps = self.identify_outlier_experiments(results, sigma_level=self.sigma_level)
        
        if len(outlier_exps) > 0:
            print(f"\nFound {len(outlier_exps)} experiments with ≥{self.outlier_trait_threshold*100:.0f}% outlier traits:\n")
            for _, row in outlier_exps.iterrows():
                print(f"  {row['sample_name'][:40]:<40} | {row['name'][:25]:<25} | "
                      f"{row['outlier_traits']:>2}/{row['total_traits']:>2} traits ({row['outlier_percentage']*100:>5.1f}%)")
            
            # Save outlier experiment list
            output_path = Path(__file__).parent.parent / self.output_dir
            output_path.mkdir(parents=True, exist_ok=True)
            outlier_file = output_path / self.config['output']['experiments_file']
            outlier_exps.to_csv(outlier_file, index=False)
            print(f"\nOutlier experiments saved to: {outlier_file}")
        else:
            print(f"\nNo experiments found with ≥{self.outlier_trait_threshold*100:.0f}% outlier traits")
        
        self.save_outlier_report(results)
        
        return results, outlier_exps


def main():
    """Main function to run outlier analysis"""
    
    config_mgr = ConfigManager()
    
    print("="*80)
    print("EvoNEST OUTLIER ANALYSIS")
    print("="*80)
    print(f"\nConfiguration:")
    print(f"  Outlier trait threshold: {config_mgr.config['analysis']['outlier_trait_threshold']*100:.0f}%")
    print(f"  Sigma level: {config_mgr.config['analysis']['sigma_level']}")
    print(f"  Output directory: {config_mgr.config['output']['output_dir']}")
    print()
    
    analyzer = OutlierAnalyzer(config_manager=config_mgr)
    results, outlier_exps = analyzer.run_analysis()
    
    # Print summary
    print(f"\n{'='*80}")
    print("SUMMARY")
    print(f"{'='*80}")
    
    total_groups = len(results)
    total_samples = sum(group['sample_count'] for group in results.values())
    
    # Count groups with outliers
    groups_with_1sigma = 0
    groups_with_2sigma = 0
    groups_with_3sigma = 0
    
    for group_data in results.values():
        has_1sigma = any(len(trait['outliers_1sigma']) > 0 for trait in group_data['traits'].values())
        has_2sigma = any(len(trait['outliers_2sigma']) > 0 for trait in group_data['traits'].values())
        has_3sigma = any(len(trait['outliers_3sigma']) > 0 for trait in group_data['traits'].values())
        
        if has_1sigma:
            groups_with_1sigma += 1
        if has_2sigma:
            groups_with_2sigma += 1
        if has_3sigma:
            groups_with_3sigma += 1
    
    print(f"Total groups analyzed: {total_groups}")
    print(f"Total samples: {total_samples}")
    print(f"Groups with 1σ outliers: {groups_with_1sigma}")
    print(f"Groups with 2σ outliers: {groups_with_2sigma}")
    print(f"Groups with 3σ outliers: {groups_with_3sigma}")
    print(f"\nOutlier experiments (≥{config_mgr.config['analysis']['outlier_trait_threshold']*100:.0f}% traits beyond {config_mgr.config['analysis']['sigma_level']}σ): {len(outlier_exps)}")


if __name__ == "__main__":
    main()
