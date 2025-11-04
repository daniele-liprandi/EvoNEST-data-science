#!/usr/bin/env python3

"""
EvoNEST Mechanical Data Processing Script
Processes tensile test data and fits polynomial models to stress-strain curves
Manages configuration in config/process_mechanics_config.json
"""

import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
from numpy.polynomial import Polynomial
from tqdm import tqdm


class ConfigManager:
    """Manages persistent configuration for mechanical data processing"""

    CONFIG_DIR = Path(__file__).parent.parent.parent / "config"
    CONFIG_FILE = CONFIG_DIR / "process_mechanics_config.json"
    
    DEFAULT_CONFIG = {
        "fracture_detection": {
            "stop_max_stress": False,
            "drop_threshold": 0.9,
            "min_points": 1
        },
        "processing": {
            "polynomial_degree": 1,
            "show_plots": False,
            "save_plots": False,
            "max_experiments": None
        },
        "output": {
            "output_dir": "processed_data"
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
    
    def interactive_setup(self):
        """Interactive setup for processing parameters"""
        self._print_header("EvoNEST Mechanical Data Processing Configuration")
        
        # Check if config exists
        config_exists = self.config_file.exists()
        
        if config_exists:
            print("\n📋 Found existing configuration:")
            self._print_current_config()
            print("\n" + "─" * 80)
            use_existing = self._prompt_yes_no(
                "Use existing configuration?",
                default=True
            )
            
            if use_existing:
                print("\n✅ Using saved configuration")
                return self.config
        
        # Setup fracture detection
        print("\n" + "═" * 80)
        self._setup_fracture_detection(config_exists)
        
        # Setup processing parameters
        print("\n" + "═" * 80)
        self._setup_processing_parameters(config_exists)
        
        # Setup output directory
        print("\n" + "═" * 80)
        self._setup_output_directory(config_exists)
        
        # Save configuration
        print("\n" + "─" * 80)
        if self._prompt_yes_no("Save this configuration for future use?", default=True):
            self.save_config()
        else:
            print("⚠️  Configuration will be used for this session only")
        
        return self.config
    
    def _setup_fracture_detection(self, config_exists):
        """Setup fracture detection parameters"""
        self._print_section("Fracture Detection")
        
        stop_max_stress = self._prompt_yes_no(
            "Stop analysis at maximum stress point?",
            default=self.config.get('fracture_detection', {}).get('stop_max_stress', False)
        )
        self.config['fracture_detection']['stop_max_stress'] = stop_max_stress
        
        if not stop_max_stress:
            drop_threshold = self._prompt_float(
                "Drop threshold for fracture detection (0.0-1.0)",
                default=self.config.get('fracture_detection', {}).get('drop_threshold', 0.9),
                min_val=0.0,
                max_val=1.0
            )
            self.config['fracture_detection']['drop_threshold'] = drop_threshold
    
    def _setup_processing_parameters(self, config_exists):
        """Setup processing parameters"""
        self._print_section("Processing Parameters")
        
        poly_degree = self._prompt_int(
            "Polynomial degree for fitting",
            default=self.config.get('processing', {}).get('polynomial_degree', 1),
            min_val=1,
            max_val=10
        )
        self.config['processing']['polynomial_degree'] = poly_degree
        
        show_plots = self._prompt_yes_no(
            "Show plots during processing?",
            default=self.config.get('processing', {}).get('show_plots', False)
        )
        self.config['processing']['show_plots'] = show_plots
        
        save_plots = self._prompt_yes_no(
            "Save plots to file?",
            default=self.config.get('processing', {}).get('save_plots', False)
        )
        self.config['processing']['save_plots'] = save_plots
        
        max_exp_input = input("Maximum experiments to process (press Enter for all): ").strip()
        if max_exp_input:
            try:
                self.config['processing']['max_experiments'] = int(max_exp_input)
            except ValueError:
                print("❌ Invalid input, using all experiments")
                self.config['processing']['max_experiments'] = None
        else:
            self.config['processing']['max_experiments'] = None
    
    def _setup_output_directory(self, config_exists):
        """Setup output directory"""
        self._print_section("Output Directory")
        
        output_dir = self._prompt_input(
            "Output directory for processed data",
            default=self.config.get('output', {}).get('output_dir', 'processed_data'),
            required=True
        )
        self.config['output']['output_dir'] = output_dir
    
    def _print_current_config(self):
        """Print current configuration"""
        print("\n┌─ Fracture Detection ───────────────────────────────────")
        fd = self.config.get('fracture_detection', {})
        print(f"│ Stop at Max Stress: {fd.get('stop_max_stress', False)}")
        print(f"│ Drop Threshold:     {fd.get('drop_threshold', 0.9)}")
        
        print("\n├─ Processing Parameters ───────────────────────────────")
        proc = self.config.get('processing', {})
        print(f"│ Polynomial Degree:  {proc.get('polynomial_degree', 1)}")
        print(f"│ Show Plots:         {proc.get('show_plots', False)}")
        print(f"│ Save Plots:         {proc.get('save_plots', False)}")
        max_exp = proc.get('max_experiments')
        print(f"│ Max Experiments:    {max_exp if max_exp else 'All'}")
        
        print("\n├─ Output ──────────────────────────────────────────────")
        print(f"│ Output Directory:   {self.config.get('output', {}).get('output_dir', 'processed_data')}")
        print("└────────────────────────────────────────────────────────")
    
    @staticmethod
    def _print_header(title):
        """Print a nice header"""
        print("\n╔" + "═" * 78 + "╗")
        print(f"║{title.center(78)}║")
        print("╚" + "═" * 78 + "╝")
    
    @staticmethod
    def _print_section(title):
        """Print a section separator"""
        print("\n┌─ " + title + " " + "─" * (74 - len(title)))
    
    @staticmethod
    def _prompt_input(prompt, default=None, required=False):
        """Prompt for text input"""
        if default:
            prompt_text = f"{prompt} [{default}]: "
        else:
            prompt_text = f"{prompt}: "
        
        while True:
            value = input(prompt_text).strip()
            
            if not value and default:
                return default
            elif not value and required:
                print("❌ This field is required!")
                continue
            elif value:
                return value
            else:
                return ""
    
    @staticmethod
    def _prompt_yes_no(prompt, default=True):
        """Prompt for yes/no"""
        default_text = "Y/n" if default else "y/N"
        prompt_text = f"{prompt} [{default_text}]: "
        
        while True:
            value = input(prompt_text).strip().lower()
            
            if not value:
                return default
            elif value in ['y', 'yes']:
                return True
            elif value in ['n', 'no']:
                return False
            else:
                print("❌ Please enter 'y' or 'n'")
    
    @staticmethod
    def _prompt_int(prompt, default=1, min_val=None, max_val=None):
        """Prompt for integer input"""
        while True:
            try:
                value = input(f"{prompt} [{default}]: ").strip()
                if not value:
                    return default
                
                int_val = int(value)
                if min_val is not None and int_val < min_val:
                    print(f"❌ Must be at least {min_val}")
                    continue
                if max_val is not None and int_val > max_val:
                    print(f"❌ Must be at most {max_val}")
                    continue
                
                return int_val
            except ValueError:
                print("❌ Please enter a valid integer")
    
    @staticmethod
    def _prompt_float(prompt, default=0.9, min_val=None, max_val=None):
        """Prompt for float input"""
        while True:
            try:
                value = input(f"{prompt} [{default}]: ").strip()
                if not value:
                    return default
                
                float_val = float(value)
                if min_val is not None and float_val < min_val:
                    print(f"❌ Must be at least {min_val}")
                    continue
                if max_val is not None and float_val > max_val:
                    print(f"❌ Must be at most {max_val}")
                    continue
                
                return float_val
            except ValueError:
                print("❌ Please enter a valid number")


class MechanicalDataProcessor:
    """Processes mechanical test data and fits polynomial models"""
    
    def __init__(self, config):
        """Initialize processor with configuration"""
        self.config = config
        self.stop_max_stress = config['fracture_detection']['stop_max_stress']
        self.drop_threshold = config['fracture_detection']['drop_threshold']
        self.min_points = config['fracture_detection']['min_points']
        self.polynomial_degree = config['processing']['polynomial_degree']
        self.show_plots = config['processing']['show_plots']
        self.save_plots = config['processing']['save_plots']
        # Setup output directory (use absolute path from project root)
        self.output_dir = Path(__file__).parent.parent.parent / config['output']['output_dir']
        
        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
    
    def detect_fracture_point(self, strain, stress):
        """
        Detect the fracture point where stress suddenly drops
        
        Parameters:
        - strain: array of strain values
        - stress: array of stress values
        
        Returns:
        - fracture_index: index where fracture occurs, or None if not detected
        """
        if len(stress) < self.min_points + 10:
            return None
        
        # Find the maximum stress point
        max_stress_idx = np.argmax(stress)
        max_stress = stress[max_stress_idx]
        
        if self.stop_max_stress:
            return max_stress_idx
        
        # Look for fracture after the maximum stress point
        for i in range(max_stress_idx, len(stress) - self.min_points):
            current_stress = stress[i]
            
            # Check if we have a significant drop from max stress
            if current_stress < max_stress * (1 - self.drop_threshold):
                return i
        
        return None
    
    def trim_curve_to_fracture(self, strain, stress):
        """
        Trim the stress-strain curve from strain=0 to the fracture point
        
        Returns:
        - trimmed_strain, trimmed_stress: trimmed arrays
        - trim_info: dictionary with trimming information
        """
        # Check if we have valid data
        if len(strain) == 0 or len(stress) == 0:
            return None, None, None
        
        # Find the index closest to strain = 0
        zero_strain_idx = int(np.argmin(np.abs(strain)))
        
        # Detect fracture point
        fracture_idx = self.detect_fracture_point(strain, stress)
        
        if fracture_idx is None:
            # If no fracture detected, use the full curve from strain=0 onwards
            end_idx = len(strain)
            fracture_detected = False
        else:
            end_idx = int(fracture_idx)
            fracture_detected = True
        
        # Trim the data
        trimmed_strain = strain[zero_strain_idx:end_idx]
        trimmed_stress = stress[zero_strain_idx:end_idx]
        
        # Create trim info with explicit type conversion to native Python types
        trim_info = {
            'original_points': int(len(strain)),
            'trimmed_points': int(len(trimmed_strain)),
            'zero_strain_idx': int(zero_strain_idx),
            'fracture_idx': int(fracture_idx) if fracture_idx is not None else None,
            'fracture_detected': bool(fracture_detected),
            'strain_range': (float(trimmed_strain.min()), float(trimmed_strain.max())),
            'stress_range': (float(trimmed_stress.min()), float(trimmed_stress.max())),
            'max_stress': float(trimmed_stress.max()) if len(trimmed_stress) > 0 else 0.0
        }
        
        return trimmed_strain, trimmed_stress, trim_info
    
    def extract_stress_strain_data(self, experiment):
        """Extract stress and strain data from experiment"""
        try:
            raw_data = experiment.get('rawData', {})
            
            strain_obj = raw_data.get('EngineeringStrain', {})
            stress_obj = raw_data.get('EngineeringStress', {})
            
            # Get the values arrays
            strain_data = strain_obj.get('values', [])
            stress_data = stress_obj.get('values', [])
            
            # Convert to numpy arrays and filter out None values
            strain_clean = []
            stress_clean = []
            
            for i in range(min(len(strain_data), len(stress_data))):
                if strain_data[i] is not None and stress_data[i] is not None:
                    strain_clean.append(strain_data[i])
                    stress_clean.append(stress_data[i])
            
            # Check if we have any valid data
            if len(strain_clean) == 0 or len(stress_clean) == 0:
                return None, None, None, None
            
            strain_array = np.array(strain_clean)
            stress_array = np.array(stress_clean)
            
            # Get sample name from metadata
            sample_name = experiment.get('metadata', {}).get('name', 'Unknown')
            
            # Trim to fracture
            strain_trimmed, stress_trimmed, trim_info = self.trim_curve_to_fracture(strain_array, stress_array)
            
            # Check if trimming failed
            if strain_trimmed is None:
                return None, None, None, None
            
            return strain_trimmed, stress_trimmed, sample_name, trim_info
        
        except (KeyError, TypeError, ValueError) as e:
            print(f"  ⚠️  Error extracting data: {e}")
            return None, None, None, None
    
    def fit_polynomial_to_experiment(self, data, experiment_id):
        """
        Fit polynomial to a single experiment
        
        Parameters:
        - data: loaded JSON data
        - experiment_id: ID of the experiment
        
        Returns:
        - dict with experiment info and polynomial coefficients, or None
        """
        try:
            experiments = data['experiments']
            if experiment_id not in experiments:
                return None
            
            experiment = experiments[experiment_id]
            strain, stress, sample_name, trim_info = self.extract_stress_strain_data(experiment)
            
            if strain is None or len(strain) < 10:
                return None
            
            # Get metadata and mechanical properties
            metadata = experiment.get('metadata', {})
            mechanical_properties = experiment.get('mechanicalProperties', {})
            
            # Fit polynomial
            p = Polynomial.fit(strain, stress, self.polynomial_degree)
            r_squared = 1 - np.sum((stress - p(strain))**2) / np.sum((stress - stress.mean())**2)
            
            # Build result
            result = {
                'experiment_id': experiment_id,
                'sample_name': sample_name,
                'type': metadata.get('type', 'tensile_test'),
                'date': metadata.get('date'),
                'polynomial_coefficients': p.coef.tolist(),
                'r_squared': float(r_squared),
                'data_points': len(strain),
                'strain_range': [float(strain.min()), float(strain.max())],
                'stress_range': [float(stress.min()), float(stress.max())],
                'fracture_detected': trim_info['fracture_detected'] if trim_info else False,
                'max_stress': trim_info['max_stress'] if trim_info else float(stress.max()),
                'trim_info': trim_info,
                'specimenDiameter': mechanical_properties.get('specimenDiameter'),
                'strainAtBreak': mechanical_properties.get('strainAtBreak'),
                'stressAtBreak': mechanical_properties.get('stressAtBreak'),
                'toughness': mechanical_properties.get('toughness'),
                'offsetYieldStrain': mechanical_properties.get('offsetYieldStrain'),
                'offsetYieldStress': mechanical_properties.get('offsetYieldStress'),
                'modulus': mechanical_properties.get('modulus'),
                'specimenName': mechanical_properties.get('specimenName'),
                'strainRate': mechanical_properties.get('strainRate'),
                'responsible': metadata.get('responsible'),
                'notes': metadata.get('notes'),
                'equipment': metadata.get('equipment'),
                'family': (experiment.get('sampleChain', [{}])[0].get('family') 
                          if experiment.get('sampleChain') and len(experiment.get('sampleChain', [])) > 0 else None),
                'genus': (experiment.get('sampleChain', [{}])[0].get('genus')
                         if experiment.get('sampleChain') and len(experiment.get('sampleChain', [])) > 0 else None),
                'species': (experiment.get('sampleChain', [{}])[0].get('species')
                           if experiment.get('sampleChain') and len(experiment.get('sampleChain', [])) > 0 else None),
                'subsampletype': (experiment.get('sampleChain', [{}])[0].get('subsampletype')
                                 if experiment.get('sampleChain') and len(experiment.get('sampleChain', [])) > 0 else None),
                'associatedTraits': [
                    {
                        'measurement': trait.get('measurement'),
                        'type': trait.get('type'),
                        'equipment': trait.get('equipment'),
                        'note': trait.get('note') or trait.get('notes'),
                        **({'detail': trait.get('detail'), 'nfibres': trait.get('nfibres')} 
                           if trait.get('type') == 'diameter' else {})
                    }
                    for trait in experiment.get('associatedTraits', [])
                ],
                'sampleChain': experiment.get('sampleChain', []),
            }
            
            # Remove None values
            result = {k: v for k, v in result.items() if v is not None}
            
            return result
        
        except Exception as e:
            print(f"  ⚠️  Error processing experiment {experiment_id}: {e}")
            return None
    
    def plot_stress_strain_with_polynomial_fit(self, strain, stress, sample_name, trim_info=None):
        """Create a plot of stress-strain curve with polynomial fit"""
        try:
            sns.set_style("whitegrid")
            plt.figure(figsize=(12, 8))
            
            # Create the main plot
            sns.scatterplot(x=strain, y=stress, alpha=0.7, s=20, color='blue', 
                          label='Experimental Data (Trimmed)')
            
            # Fit and plot polynomial
            p = Polynomial.fit(strain, stress, self.polynomial_degree)
            strain_smooth = np.linspace(strain.min(), strain.max(), 300)
            stress_fit = p(strain_smooth)
            
            plt.plot(strain_smooth, stress_fit, 'r-', linewidth=2, 
                    label=f'{self.polynomial_degree}th Degree Polynomial Fit')
            
            # Customize the plot
            plt.xlabel('Engineering Strain', fontsize=12)
            plt.ylabel('Engineering Stress (MPa)', fontsize=12)
            plt.title(f'Stress-Strain Curve: {sample_name}\n(Trimmed from strain=0 to fracture)', 
                     fontsize=14, fontweight='bold')
            plt.legend(fontsize=10)
            plt.grid(True, alpha=0.3)
            
            # Add statistics
            r_squared = 1 - np.sum((stress - p(strain))**2) / np.sum((stress - stress.mean())**2)
            info_text = f'R² = {r_squared:.4f}'
            if trim_info:
                info_text += f'\nData points: {trim_info["trimmed_points"]} / {trim_info["original_points"]}'
                if trim_info['fracture_detected']:
                    info_text += '\nFracture: Detected'
            
            plt.text(0.05, 0.95, info_text, transform=plt.gca().transAxes,
                    bbox=dict(boxstyle='round', facecolor='white', alpha=0.8),
                    verticalalignment='top', fontsize=10)
            
            plt.tight_layout()
            return plt.gcf()
        
        except Exception as e:
            print(f"  ⚠️  Error creating plot: {e}")
            return None
    
    def process_all_experiments(self, data):
        """
        Process all experiments and extract polynomial coefficients
        
        Returns:
        - list of results for each experiment
        """
        experiments = data['experiments']
        experiment_ids = list(experiments.keys())
        
        max_exp = self.config['processing']['max_experiments']
        if max_exp:
            experiment_ids = experiment_ids[:max_exp]
        
        results = []
        processed = 0
        failed = 0
        
        print(f"\n📊 Processing {len(experiment_ids)} experiments...")
        
        # Process with progress bar
        for exp_id in tqdm(experiment_ids, desc="Processing", unit="exp", ncols=80):
            result = self.fit_polynomial_to_experiment(data, exp_id)
            
            if result:
                results.append(result)
                processed += 1
                
                # Save plot if requested
                if self.save_plots:
                    experiments_data = data['experiments'][exp_id]
                    strain, stress, sample_name, trim_info = self.extract_stress_strain_data(experiments_data)
                    if strain is not None:
                        fig = self.plot_stress_strain_with_polynomial_fit(strain, stress, sample_name, trim_info)
                        if fig:
                            # Build filename with taxonomic information
                            sample_chain = experiments_data.get('sampleChain', [])
                            family = sample_chain[0].get('family', 'unknown') if sample_chain else 'unknown'
                            genus = sample_chain[0].get('genus', 'unknown') if sample_chain else 'unknown'
                            species = sample_chain[0].get('species', 'unknown') if sample_chain else 'unknown'
                            
                            # Clean names for filesystem (replace spaces and special chars)
                            family = str(family).replace(' ', '_').replace('/', '_') if family else 'unknown'
                            genus = str(genus).replace(' ', '_').replace('/', '_') if genus else 'unknown'
                            species = str(species).replace(' ', '_').replace('/', '_') if species else 'unknown'
                            
                            plot_file = self.output_dir / f"{family}_{genus}_{species}_{exp_id}.png"
                            fig.savefig(plot_file, dpi=150, bbox_inches='tight')
                            plt.close(fig)
            else:
                failed += 1
        
        print(f"✅ Completed: {processed} successful, {failed} failed out of {len(experiment_ids)} experiments")
        return results
    
    def save_results(self, results, filename='hierarchical_experiment_data_no_curves.json'):
        """Save polynomial coefficients and experimental data to JSON file"""
        output_data = {
            'metadata': {
                'total_experiments': len(results),
                'polynomial_degree': self.polynomial_degree,
                'processing_date': '2025-10-21',
                'fracture_detection': {
                    'stop_max_stress': self.stop_max_stress,
                    'drop_threshold': self.drop_threshold,
                    'min_points': self.min_points
                }
            },
            'experiments': {}
        }
        
        for result in results:
            exp_id = result['experiment_id']
            output_data['experiments'][exp_id] = result
        
        output_path = self.output_dir / filename
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, indent=2, ensure_ascii=False)
        
        print(f"\n💾 Results saved to {output_path}")
        return output_path


def load_experiments_data(json_file_path):
    """Load experiments data from JSON file"""
    try:
        with open(json_file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        if 'experiments' in data:
            return data
        else:
            raise ValueError("JSON file must contain 'experiments' key")
    except FileNotFoundError:
        print(f"❌ Error: File not found: {json_file_path}")
        raise
    except json.JSONDecodeError:
        print(f"❌ Error: Invalid JSON in {json_file_path}")
        raise


def main():
    """Main function to process mechanical data"""
    
    print("\n" + "═" * 80)
    print("EvoNEST Mechanical Data Processing - Python")
    print("═" * 80)
    
    # Load or setup configuration
    config_manager = ConfigManager()
    config = config_manager.interactive_setup()
    
    print("\n╔" + "═" * 78 + "╗")
    print(f"║{'Processing Configuration'.center(78)}║")
    print("╚" + "═" * 78 + "╝")
    
    proc = config['processing']
    fd = config['fracture_detection']
    print(f"\n📊 Polynomial Degree: {proc['polynomial_degree']}")
    print(f"🔍 Stop at Max Stress: {fd['stop_max_stress']}")
    print(f"📁 Output Directory: {config['output']['output_dir']}")
    print(f"📈 Show Plots: {proc['show_plots']}")
    print(f"💾 Save Plots: {proc['save_plots']}")
    print("\n" + "─" * 80)
    
    # Create processor
    processor = MechanicalDataProcessor(config)
    
    try:
        # Load experiments data
        data_path = Path(__file__).parent.parent.parent / "downloaded_data" / "experiments_data.json"
        print(f"\n📂 Loading experiments from: {data_path}")
        data = load_experiments_data(str(data_path))
        print(f"✅ Loaded {len(data['experiments'])} experiments")
        
        # Process all experiments
        results = processor.process_all_experiments(data)
        
        # Save results
        processor.save_results(results, 'hierarchical_experiment_data_no_curves.json')
        
        print("\n" + "═" * 80)
        print("✅ Processing complete!")
        print("═" * 80 + "\n")
    
    except FileNotFoundError as e:
        print(f"\n❌ Error: {e}")
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
