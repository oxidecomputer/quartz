import zipfile
import datetime
import pathlib
import sys


import tomli

from fpga_releaser.archive_parser import get_relevant_files_from_buck_zip
from fpga_releaser import config_toml

def filter_wtih_exclusions(path, exclusions):
        for e in exclusions:
            if e in path:
                return False
        return True

class FPGAImage:
    def __init__(self, name, job_name, hubris_path, toolchain, builder):
        self.name = name
        self.job_name = job_name
        self.hubris_path = hubris_path
        self.toolchain = toolchain
        self.builder = builder
        self.archive = None
        self.filenames = []
        self._timestamp = datetime.datetime.now()
        self.gh_release_name = ""
        self.gh_release_url = ""
        self.gh_build_sha = ""

    @classmethod
    def from_dict(cls, fpga_name, data: dict):
        return cls(
            name=fpga_name,
            job_name=data[fpga_name].get("job_name"),
            hubris_path=data[fpga_name].get("hubris_path"),
            toolchain=data[fpga_name].get("toolchain"),
            builder=data[fpga_name].get("builder"),
        )
    
    @property
    def timestamp(self):
        return self._timestamp.strftime("%Y-%m-%d-%H%M%S")
    
    def _filter_names(self, exclusions=None):
        if exclusions is None:
            exclusions = []
        else:
            exclusions = set(exclusions)
        filtered_filenames = [x for x in self.filenames if filter_wtih_exclusions(x, exclusions)]
        return filtered_filenames
    
    def materialize_relevant_files(self, export_path, exclusions=None):
        if not pathlib.Path(export_path).exists():
            print(f"{export_path} does not exist, create it first or check your paths")
            sys.exit(1)
        fnames = []
        for filename in self._filter_names(exclusions):
            zpath = pathlib.Path(filename)
            full_export_path = pathlib.Path(export_path) / zpath.name
            with self.archive.open(filename, "r") as fin, open(full_export_path, "wb") as fout:
                fout.write(fin.read())
                fnames.append(zpath.name)
        if self.gh_release_url:
            readme = pathlib.Path("README.md")
            full_export_path = pathlib.Path(export_path) / readme
            with open(full_export_path, 'w') as fout:
                fout.write(self.make_readme_contents())
                fnames.append(readme.name)
        return fnames

    
    def add_archive(self, archive: zipfile.ZipFile):
        """
        Add an archive to the FPGA image as a ZipFile object
        """
        self.archive = archive
        if self.builder == "buck2":
            self.filenames = get_relevant_files_from_buck_zip(self.archive)

    def add_build_sha(self, sha):
        self.gh_build_sha = sha

    def add_release_url(self, url):
        self.gh_release_url = url

    def report_timing(self):
        log = self._get_timing_report()
        if self.toolchain == "yosys":
            import fpga_releaser.yosys as yosys
            yosys.check_and_report_timing(log)

    def report_utilization(self):
        log = self._get_fit_report()
        if self.toolchain == "yosys":
            import fpga_releaser.yosys as yosys
            yosys.report_utilization(self._get_fit_report())

    def _get_nextpnr_log(self):
        if self.toolchain == "yosys":
            for filename in self.filenames:
                if "nextpnr.log" in filename:
                    with self.archive.open(filename, "r") as f:
                        return f.read().decode("utf-8")
        else:
            raise ValueError(f"Unsupported toolchain ({self.toolchain}) for nextpnr log retrieval.")
        
    def _get_vivado_timing_log(self):
        if self.toolchain == "vivado":
            for filename in self.filenames:
                if "route_timing.rpt" in filename:
                    with self.archive.open(filename, "r") as f:
                        return f.read().decode("utf-8")
        else:
            raise ValueError(f"Unsupported toolchain ({self.toolchain}) for vivado log retrieval.")
        
    def _get_vivado_fit_log(self):
        if self.toolchain == "vivado":
            for filename in self.filenames:
                if "place_optimize_utilization.rpt" in filename:
                    with self.archive.open(filename, "r") as f:
                        return f.read().decode("utf-8")
        else:
            raise ValueError(f"Unsupported toolchain ({self.toolchain}) for vivado log retrieval.")

    def _get_timing_report(self):
        if self.toolchain == "yosys":
            return self._get_nextpnr_log()
        elif self.toolchain == "vivado":
             return self._get_vivado_timing_log()
        else:
            raise NotImplementedError

    def _get_fit_report(self):
        if self.toolchain == "yosys":
            return self._get_nextpnr_log()
        elif self.toolchain == "vivado":
             return self._get_vivado_fit_log()
        else:
            raise NotImplementedError
        
    def make_readme_contents(self):
        txt = ("FPGA images and collateral are generated from:\n"
               f"[this sha](https://github.com/oxidecomputer/quartz/commit/{self.gh_build_sha})\n"
               f"[release]({self.gh_release_url})")
        return txt
        

def get_config(fpga_name):
    """
    Get the configuration for the specified FPGA name.
    """
    with open(config_toml, "rb") as f:
        config = tomli.load(f)

        print(config.keys())

    known_fpga = config.get(fpga_name, None)
    if known_fpga is None:
        raise ValueError(f"FPGA {fpga_name} not found in config.")

    return FPGAImage.from_dict(fpga_name, config)
            
