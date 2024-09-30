import argparse

from pathlib import Path

import matplotlib.ticker as mtick
import matplotlib.pyplot as plt
import pandas as pd


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Parse TPC-C data from a text file.")
    parser.add_argument(
        "dirs",
        type=str,
        nargs=2,
        help="Pattern for selecting all console output files",
    )
    args = parser.parse_args()

    throughputs_all = {}
    for dir in args.dirs:
        dfs = {}
        for path in Path(dir).glob("*_cr.csv"):
            thread_count = int(str(path).split("_")[2])
            dfs[thread_count] = pd.read_csv(path)
            print(dfs[thread_count]["wal_write_gib"].mean())

        avg_thoughput = []
        throughputs_all[dir] = avg_thoughput
        for (thread_count, df) in dfs.items():
            avg_thoughput.append([thread_count, df["wal_write_gib"].mean()])

    throughputs_dfs = {}
    for key, throughputs in throughputs_all.items():
        throughputs_dfs[key] = pd.DataFrame(
            throughputs, columns=["threads", "wal_write_gib"]
        )

    assert (throughputs_dfs[args.dirs[0]]["threads"] == throughputs_dfs[args.dirs[1]]["threads"]).all()

    fig, axes = plt.subplots(1, 1)
    for df in throughputs_dfs.values():
        axes.plot(df["threads"], df["wal_write_gib"], label=dir)

    axes.set_xticks(throughputs_dfs[args.dirs[0]]["threads"])
    axes.set_xlabel("Worker threads")
    axes.set_ylabel("GiB/s")
    axes.legend()
    fig.suptitle("Average WAL throughput")
    fig.savefig("wal_write.png", bbox_inches="tight", dpi=600)
