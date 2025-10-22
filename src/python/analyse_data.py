#!/usr/bin/env python3

"""
EvoNEST Data Analysis - Table Building Script
Loads data from EvoNEST and processes it into structured tables for analysis
Manages configuration in config/analyse_data_config.json
"""

import json
from pathlib import Path
from typing import Dict, Tuple

import pandas as pd


class ConfigManager:
    """Manages persistent configuration for data analysis"""

    CONFIG_DIR = Path(__file__).parent.parent / "config"
    CONFIG_FILE = CONFIG_DIR / "analyse_data_config.json"

    DEFAULT_CONFIG = {
        "paths": {
            "downloaded_data_dir": "downloaded_data",
            "processed_data_dir": "processed_data"
        },
        "output": {
            "save_tables": False,
            "output_format": "csv"
        }
    }

    def __init__(self):
        """Initialize config manager"""
        self.config_dir = self.CONFIG_DIR
        self.config_file = self.CONFIG_FILE
        self.config = self.load_config()

    def load_config(self) -> Dict:
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

    def save_config(self) -> bool:
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

    def _merge_configs(self, default: Dict, saved: Dict) -> Dict:
        """Recursively merge saved config with defaults"""
        result = default.copy()
        for key, value in saved.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self._merge_configs(result[key], value)
            else:
                result[key] = value
        return result


def load_data(config: Dict) -> Tuple[Dict, Dict, Dict]:
    """Load all data files from downloaded_data and processed_data folders."""
    print("📂 Loading data files...")

    # Define data paths from config
    base_dir = Path(__file__).parent.parent
    data_dir = base_dir / config['paths']['downloaded_data_dir']
    processed_dir = base_dir / config['paths']['processed_data_dir']

    # Load samples data
    with open(data_dir / 'samples_data.json', 'r', encoding='utf-8') as f:
        samples_json = json.load(f)
    print(f"  ✓ Loaded {len(samples_json['samples'])} samples")

    # Load traits data
    with open(data_dir / 'traits_data.json', 'r', encoding='utf-8') as f:
        traits_json = json.load(f)
    print(f"  ✓ Loaded {len(traits_json['traits'])} traits")

    # Load processed experiments data
    with open(processed_dir / 'hierarchical_experiment_data_no_curves.json', 'r', encoding='utf-8') as f:
        experiments_json = json.load(f)
    print(f"  ✓ Loaded {len(experiments_json['experiments'])} experiments")

    print()
    return samples_json, traits_json, experiments_json


def build_samples_table(samples_json):
    """Build samples DataFrame from JSON data."""
    print("🔨 Building samples table...")
    
    # Convert to DataFrame using json_normalize
    samples_df = pd.json_normalize(samples_json['samples'])
    
    print(f"  ✓ Samples DataFrame: {samples_df.shape[0]} rows × {samples_df.shape[1]} columns")
    
    # Display sample types distribution
    if 'type' in samples_df.columns:
        sample_types = samples_df['type'].value_counts()
        print("  Sample types:")
        for type_name, count in sample_types.items():
            print(f"    - {type_name}: {count}")
    
    print()
    return samples_df


def build_traits_table(traits_json):
    """Build traits DataFrame from JSON data."""
    print("🔨 Building traits table...")
    
    # Convert to DataFrame using json_normalize
    traits_df = pd.json_normalize(traits_json['traits'])
    
    print(f"  ✓ Traits DataFrame: {traits_df.shape[0]} rows × {traits_df.shape[1]} columns")
    
    # Display trait types distribution
    if 'type' in traits_df.columns:
        trait_types = traits_df['type'].value_counts()
        print(f"  Trait types: {len(trait_types)} unique types")
        print("  Top trait types:")
        for type_name, count in trait_types.head(5).items():
            print(f"    - {type_name}: {count}")
    
    print()
    return traits_df


def build_experiments_table(experiments_json):
    """Build experiments DataFrame from processed data."""
    print("🔨 Building experiments table...")
    
    # Convert experiments dict to list of records
    experiments_list = []
    for exp_id, exp_data in experiments_json['experiments'].items():
        # Flatten the nested structure
        exp_record = {
            'experiment_id': exp_id,
            'sample_name': exp_data.get('sample_name'),
            'type': exp_data.get('type'),
            'date': exp_data.get('date'),
            'r_squared': exp_data.get('r_squared'),
            'data_points': exp_data.get('data_points'),
            'fracture_detected': exp_data.get('fracture_detected'),
            'max_stress': exp_data.get('max_stress'),
            'responsible': exp_data.get('responsible'),
            'notes': exp_data.get('notes'),
            'equipment': exp_data.get('equipment'),
            'family': exp_data.get('family'),
            'genus': exp_data.get('genus'),
            'species': exp_data.get('species'),
            'subsampletype': exp_data.get('subsampletype'),
        }
        
        # Add strain and stress ranges
        if 'strain_range' in exp_data:
            exp_record['strain_min'] = exp_data['strain_range'][0]
            exp_record['strain_max'] = exp_data['strain_range'][1]
        
        if 'stress_range' in exp_data:
            exp_record['stress_min'] = exp_data['stress_range'][0]
            exp_record['stress_max'] = exp_data['stress_range'][1]
        
        # Store polynomial coefficients as list
        exp_record['polynomial_coefficients'] = exp_data.get('polynomial_coefficients')
        
        experiments_list.append(exp_record)
    
    experiments_df = pd.DataFrame(experiments_list)
    
    print(f"  ✓ Experiments DataFrame: {experiments_df.shape[0]} rows × {experiments_df.shape[1]} columns")
    print()
    
    return experiments_df


def print_summary(samples_df, traits_df, experiments_df):
    """Print summary statistics for all tables."""
    print("=" * 80)
    print("DATA SUMMARY")
    print("=" * 80)
    print()
    
    print("📊 SAMPLES")
    print(f"  Total samples: {len(samples_df)}")
    if 'type' in samples_df.columns:
        sample_counts = samples_df['type'].value_counts()
        print("  Sample types:")
        for type_name, count in sample_counts.items():
            print(f"    - {type_name}: {count}")
    if 'family' in samples_df.columns:
        print(f"  Families represented: {samples_df['family'].nunique()}")
    
    print("\n🔬 TRAITS")
    print(f"  Total traits: {len(traits_df)}")
    if 'type' in traits_df.columns:
        print(f"  Trait types: {traits_df['type'].nunique()} unique types")
    
    print("\n⚗️ EXPERIMENTS")
    print(f"  Total experiments: {len(experiments_df)}")
    if 'r_squared' in experiments_df.columns:
        print(f"  Average R²: {experiments_df['r_squared'].mean():.4f}")
    if 'fracture_detected' in experiments_df.columns:
        print(f"  Fracture detected: {experiments_df['fracture_detected'].sum()} / {len(experiments_df)}")
    if 'family' in experiments_df.columns:
        print(f"  Families tested: {experiments_df['family'].nunique()}")
    
    print()
    print("=" * 80)


def main() -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Main function to build all data tables."""
    print("\n" + "═" * 80)
    print("EvoNEST Data Analysis - Building Data Tables")
    print("═" * 80)
    print()

    # Load configuration
    config_manager = ConfigManager()
    config = config_manager.config

    # Load data
    samples_json, traits_json, experiments_json = load_data(config)

    # Build tables
    samples_df = build_samples_table(samples_json)
    traits_df = build_traits_table(traits_json)
    experiments_df = build_experiments_table(experiments_json)

    # Print summary
    print_summary(samples_df, traits_df, experiments_df)

    print("\n✅ Data tables built successfully!")
    print("   Available DataFrames: samples_df, traits_df, experiments_df")
    print("\n💡 Next steps: Explore data and create visualizations with seaborn/matplotlib")
    print("═" * 80 + "\n")

    return samples_df, traits_df, experiments_df


if __name__ == "__main__":
    samples_df, traits_df, experiments_df = main()
