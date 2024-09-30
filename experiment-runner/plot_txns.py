import argparse

from pathlib import Path

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
        for path in Path(dir).glob("*_stdout.txt"):
            rows = []
            with open(path, "r") as f:
                for line in f.readlines():
                    line = line.strip()
                    if line.startswith("|") and line.endswith("|"):
                        cols = []
                        rows.append(cols)
                        for col in line.split("|")[1:-1]:
                            cols.append(col.strip().strip("-"))

            headers = []
            for h1, h2 in zip(rows[0], rows[1]):
                if h2 != "":
                    headers.append(f"{h1} {h2}")
                else:
                    headers.append(h1)

            data_rows = []
            for cols in rows[2:]:
                data_cols = []
                data_rows.append(data_cols)
                for col in cols:
                    if col != "":
                        data_cols.append(float(col))
                    else:
                        data_cols.append(0)

            dfs[path] = pd.DataFrame(data_rows, columns=headers)

        throughputs = []
        throughputs_all[dir] = throughputs
        for name, df in dfs.items():
            thread_count = int(str(name).split("_")[2])
            throughput = df["OLTP TX"].mean()
            throughputs.append([thread_count, throughput])

    throughputs_dfs = {}
    for key, throughputs in throughputs_all.items():
        throughputs_dfs[key] = pd.DataFrame(
            throughputs, columns=["threads", "throughputs"]
        )

    assert (throughputs_dfs[args.dirs[0]]["threads"] == throughputs_dfs[args.dirs[1]]["threads"]).all()

    fig, axes = plt.subplots(1, 1)
    for dir, df in throughputs_dfs.items():
        axes.plot(df["threads"], df["throughputs"], label=dir)

    axes.set_xticks(throughputs_dfs[args.dirs[0]]["threads"])
    axes.set_xlabel("Worker threads")
    axes.set_ylabel("TX/s")
    axes.legend()
    fig.suptitle("Average TX throughput")
    fig.savefig("tx_per_sec.png", bbox_inches="tight", dpi=600)
