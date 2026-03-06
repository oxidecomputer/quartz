# We're going to be handed a zip archive of the buck2 build
# It contains a directory with some hash name
# For a yosys build we're going to need the following things:
# the bz2 file
# the nextpnr log at that same directory called nextpnr.log
# all the stuff in the _maps_ directory at that same level

def _matches_fpga(fpga_name, filename):
    return fpga_name in filename or fpga_name.replace('-', '_') in filename


def get_relevant_files_from_buck_zip(fpga_name, zip):
    # Local builds (--local) zip the full buck-out tree containing multiple
    # projects, so we filter by fpga name.  GitHub artifact zips are
    # single-project with shallow paths — no filtering needed.  Distinguish
    # by checking max path depth: buck-out trees have deeply nested paths.
    all_names = [item.filename for item in zip.infolist()]
    max_depth = max((name.count('/') for name in all_names), default=0)
    filter_by_name = max_depth > 2

    zip_names = []
    for item in zip.infolist():
        if filter_by_name:
            if not _matches_fpga(fpga_name, item.filename):
                continue
        if item.filename.endswith(".bz2"):
            zip_names.append(item.filename)
        if "maps/" in item.filename and (item.filename.endswith(".json") or item.filename.endswith(".html")):
            zip_names.append(item.filename)
        if item.filename.endswith("nextpnr.log"):
           zip_names.append(item.filename)
        # Vivado stuff
        if item.filename.endswith("route_timing.rpt"):
            zip_names.append(item.filename)
        if item.filename.endswith("place_optimize_utilization.rpt"):
            zip_names.append(item.filename)
        if item.filename.endswith("synthesize.log"):
            zip_names.append(item.filename)
        if item.filename.endswith("route.log"):
            zip_names.append(item.filename)
        if item.filename.endswith("place.log"):
            zip_names.append(item.filename)
        if item.filename.endswith("optimize.log"):
            zip_names.append(item.filename)

    return zip_names