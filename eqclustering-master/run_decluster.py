from eqclustering import BPTree
# Basic use
t = BPTree.from_file("zaliapin_data.txt")  # Load event data from a file
t.grow()  # Populate B-P tree with events
t.prune(c=None)  # Prune tree using cutoff distance (calculate if None)
t.output2file("zaliapin_output.txt")  # Output to file
