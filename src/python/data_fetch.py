#!/usr/bin/env python3

"""
EvoNEST Data Fetch Script
Fetches data from EvoNEST API and saves to downloaded_data/
Manages configuration in config/evonest_config.json
"""

import json
from pathlib import Path

import requests


class ConfigManager:
    """Manages persistent configuration for EvoNEST data fetching"""
    
    CONFIG_DIR = Path(__file__).parent.parent.parent / "config"
    CONFIG_FILE = CONFIG_DIR / "evonest_config.json"
    
    DEFAULT_CONFIG = {
        "api": {
            "api_key": "",
            "database": "",
            "base_url": ""
        },
        "fetch_options": {
            "include_related": False,
            "include_raw_data": False,
            "include_original": False,
            "include_sample_features": False
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
    
    def has_api_credentials(self):
        """Check if API credentials are configured"""
        api_key = self.config.get('api', {}).get('api_key')
        database = self.config.get('api', {}).get('database')
        return bool(api_key and api_key != "" and database)
    
    def interactive_setup(self):
        """Interactive setup for API credentials and options"""
        self._print_header("EvoNEST Data Fetch Configuration")
        
        # Check if config exists
        config_exists = self.config_file.exists()
        
        if config_exists and self.has_api_credentials():
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
        
        # Setup API credentials
        print("\n" + "═" * 80)
        self._setup_api_credentials(config_exists)
        
        # Setup fetch options
        print("\n" + "═" * 80)
        # If no config exists, always configure options (first-time setup)
        # If config exists, ask the user
        if not config_exists:
            configure_options = True
        else:
            configure_options = self._prompt_yes_no(
                "Configure advanced fetch options?",
                default=False
            )
        
        if configure_options:
            self._setup_fetch_options()
        else:
            print("\n✅ Using default fetch options")
        
        # Save configuration
        print("\n" + "─" * 80)
        if self._prompt_yes_no("Save this configuration for future use?", default=True):
            self.save_config()
        else:
            print("⚠️  Configuration will be used for this session only")
        
        return self.config
    
    def _setup_api_credentials(self, config_exists):
        """Setup API credentials"""
        self._print_section("API Credentials")

        # Base URL
        current_url = self.config.get('api', {}).get('base_url')
        print("\n💡 EvoNEST API base URL (use default unless you have a custom instance)")
        base_url = self._prompt_input(
            "Enter API base URL",
            default=current_url,
            required=True
        )
        self.config['api']['base_url'] = base_url

        # API Key
        current_key = self.config.get('api', {}).get('api_key')
        if current_key and config_exists:
            masked_key = current_key[:8] + "..." + current_key[-4:] if len(current_key) > 12 else "***"
            print(f"\nCurrent API key: {masked_key}")

        print("\n💡 To get your API key: Click your avatar (top right) → API Keys → Generate new key")
        api_key = self._prompt_input(
            "Enter API key (format: evo_xxxxx)",
            default=current_key if config_exists else None,
            required=True
        )
        self.config['api']['api_key'] = api_key

        # Database
        current_db = self.config.get('api', {}).get('database')
        print("\n💡 Database name is shown in the top right corner of EvoNEST, near your avatar")
        database = self._prompt_input(
            "Enter database name",
            default=current_db,
            required=True
        )
        self.config['api']['database'] = database
    
    def _setup_fetch_options(self):
        """Setup fetch options"""
        self._print_section("Fetch Options")
        
        print("\n💡 Related: Include hierarchical parent/sample chain within data structures")
        include_related = self._prompt_yes_no(
            "Include related/parent chain information?",
            default=self.config.get('fetch_options', {}).get('include_related', False)
        )
        self.config['fetch_options']['include_related'] = include_related
        
        print("\n💡 Sample Features: Add sample columns to trait measurements (flattened)")
        include_sample_features = self._prompt_yes_no(
            "Include sample features in traits?",
            default=self.config.get('fetch_options', {}).get('include_sample_features', False)
        )
        self.config['fetch_options']['include_sample_features'] = include_sample_features
        
        include_raw_data = self._prompt_yes_no(
            "Include raw experimental data?",
            default=self.config.get('fetch_options', {}).get('include_raw_data', False)
        )
        self.config['fetch_options']['include_raw_data'] = include_raw_data
        
        include_original = self._prompt_yes_no(
            "Include original unprocessed data?",
            default=self.config.get('fetch_options', {}).get('include_original', False)
        )
        self.config['fetch_options']['include_original'] = include_original
    
    def _print_current_config(self):
        """Print current configuration"""
        print("\n┌─ API Settings ──────────────────────────────────────────")
        print(f"│ Base URL: {self.config.get('api', {}).get('base_url')}")
        api_key = self.config.get('api', {}).get('api_key')
        masked_key = api_key[:8] + "..." + api_key[-4:] if api_key and len(api_key) > 12 else "Not set"
        print(f"│ API Key:  {masked_key}")
        print(f"│ Database: {self.config.get('api', {}).get('database')}")
        
        print("\n├─ Fetch Options ────────────────────────────────────────")
        opts = self.config.get('fetch_options', {})
        print(f"│ Include Related:        {opts.get('include_related', False)}")
        print(f"│ Include Sample Features: {opts.get('include_sample_features', False)}")
        print(f"│ Include Raw Data:       {opts.get('include_raw_data', False)}")
        print(f"│ Include Original:       {opts.get('include_original', False)}")
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


class EvoNESTClient:
    """Client for interacting with the EvoNEST API"""
    
    def __init__(self, api_key, database, base_url="https://evonest.zoologie.uni-greifswald.de"):
        """Initialize the EvoNEST API client"""
        self.api_key = api_key
        self.database = database
        self.base_url = base_url
        print(f"✅ EvoNEST Client initialized for database: {database}")
    
    def _get_headers(self):
        """Get authorization headers"""
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
    
    def get_samples(self, include_related=False, sample_type=None, family=None):
        """Retrieve samples from the EvoNEST API"""
        print("📊 Fetching samples from EvoNEST API...")
        
        params = {"database": self.database}
        if include_related:
            params["related"] = "true"
        if sample_type:
            params["type"] = sample_type
        if family:
            params["family"] = family
        
        try:
            response = requests.get(
                f"{self.base_url}/api/samples/ext",
                headers=self._get_headers(),
                params=params
            )
            
            if response.status_code == 401:
                print("❌ Authentication failed. API key may be invalid.")
                return None
            elif response.status_code == 403:
                print("❌ Access denied. Check your API key and database permissions.")
                return None
            elif response.status_code == 500:
                print("❌ Server error. Database connection may be unavailable.")
                return None
            elif response.status_code != 200:
                print(f"❌ Error: Status code {response.status_code}")
                print(f"   Response: {response.text}")
                return None
            
            samples = response.json()
            print(f"✅ Successfully retrieved {len(samples['samples'])} samples\n")
            return samples
        
        except requests.exceptions.RequestException as e:
            print(f"❌ Request error: {e}")
            return None
    
    def get_traits(self, include_sample_features=True):
        """Retrieve trait measurements from the EvoNEST API"""
        print("📊 Fetching traits from EvoNEST API...")
        
        params = {
            "database": self.database,
            "includeSampleFeatures": str(include_sample_features).lower()
        }
        
        try:
            response = requests.get(
                f"{self.base_url}/api/traits/ext",
                headers=self._get_headers(),
                params=params
            )
            
            if response.status_code == 200:
                traits = response.json()
                print(f"✅ Successfully retrieved {len(traits['traits'])} traits\n")
                return traits
            else:
                print(f"❌ Error fetching traits: {response.status_code}")
                return None
        
        except requests.exceptions.RequestException as e:
            print(f"❌ Request error: {e}")
            return None
    
    def get_experiments(self, include_raw_data=False, include_original=False, include_related=False):
        """Retrieve experiments from the EvoNEST API"""
        print("📊 Fetching experiments from EvoNEST API...")
        
        params = {"database": self.database}
        if include_raw_data:
            params["includeRawData"] = "true"
        if include_original:
            params["includeOriginal"] = "true"
        if include_related:
            params["includeRelated"] = "true"
        
        try:
            response = requests.get(
                f"{self.base_url}/api/experiments/ext",
                headers=self._get_headers(),
                params=params
            )
            
            if response.status_code == 200:
                experiments = response.json()
                print(f"✅ Successfully retrieved {len(experiments['experiments'])} experiments\n")
                return experiments
            else:
                print(f"❌ Error fetching experiments: {response.status_code}")
                return None
        
        except requests.exceptions.RequestException as e:
            print(f"❌ Request error: {e}")
            return None


def save_data(data, filename):
    """Save data to JSON file in downloaded_data folder"""
    output_dir = Path(__file__).parent.parent.parent / "downloaded_data"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    output_file = output_dir / filename
    
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"💾 Data saved to '{output_file}'")
        return True
    except IOError as e:
        print(f"❌ Error saving data: {e}")
        return False


def main():
    """Main function to fetch EvoNEST data"""
    
    print("\n" + "═" * 80)
    print("EvoNEST Data Fetch - Python")
    print("═" * 80)
    
    # Load or setup configuration
    config_manager = ConfigManager()
    config = config_manager.interactive_setup()
    
    api_key = config['api']['api_key']
    database = config['api']['database']
    base_url = config['api'].get('base_url', 'https://evonest.zoologie.uni-greifswald.de')
    
    if not api_key or not database:
        print("\n❌ Error: API key and database are required!")
        return
    
    # Create client
    print("\n" + "═" * 80)
    client = EvoNESTClient(api_key=api_key, database=database, base_url=base_url)
    
    try:
        fetch_opts = config.get('fetch_options', {})
        
        # Fetch samples
        print("\n" + "=" * 80)
        print("FETCHING SAMPLES")
        print("=" * 80 + "\n")
        samples = client.get_samples(include_related=fetch_opts.get('include_related', False))
        
        if samples:
            save_data(samples, "samples_data.json")
        
        # Fetch traits
        print("\n" + "=" * 80)
        print("FETCHING TRAITS")
        print("=" * 80 + "\n")
        traits = client.get_traits(include_sample_features=fetch_opts.get('include_sample_features', True))
        
        if traits:
            save_data(traits, "traits_data.json")
        
        # Fetch experiments
        print("\n" + "=" * 80)
        print("FETCHING EXPERIMENTS")
        print("=" * 80 + "\n")
        experiments = client.get_experiments(
            include_raw_data=fetch_opts.get('include_raw_data', False),
            include_original=fetch_opts.get('include_original', False),
            include_related=True
        )
        
        if experiments:
            save_data(experiments, "experiments_data.json")
        
        print("\n" + "=" * 80)
        print("✅ Data fetch complete!")
        print("=" * 80)
    
    except Exception as e:
        print(f"\n❌ Error during data fetch: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
