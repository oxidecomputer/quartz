# We're going to be handed a zip archive of the buck2 build
# It contains a directory with some hash name
# For a yosys build we're going to need the following things:
# the bz2 file
# the nextpnr log at that same directory called nextpnr.log
# all the stuff in the _maps_ directory at that same level

def get_relevant_files_from_buck_zip(fpga_name, zip):
    zip_names = []
    for item in zip.infolist():
        # folders use _ instead of -
        if fpga_name not in item.filename and fpga_name.replace('-', '_') not in item.filename:
            # filter out stuff without the fpga name in it
            # (might be other projects if local build etc)
            continue
        if item.filename.endswith(".bz2"):
            zip_names.append(item.filename)
        if "/maps/" in item.filename and (item.filename.endswith(".json") or item.filename.endswith(".html")):
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