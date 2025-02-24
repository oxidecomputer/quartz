import importlib.resources as resources

files = resources.files(__name__)
config_toml = files / "config.toml"