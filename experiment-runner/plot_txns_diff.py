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

    diffs = []
    for throughput_baseline, throughput_bookkeeper in zip(
        throughputs_all[args.dirs[0]],
        throughputs_all[args.dirs[1]],
    ):
        assert throughput_baseline[0] == throughput_bookkeeper[0]
        diffs.append(
            [
                throughput_baseline[0],
                (throughput_baseline[1] - throughput_bookkeeper[1])
                / throughput_baseline[1]
                * 100,
            ]
        )

    df_diffs = pd.DataFrame(diffs, columns=["threads", "diffs"])
    print(df_diffs)

    fig, axes = plt.subplots(1, 1)
    axes.bar(df_diffs["threads"], df_diffs["diffs"], width=2)
    axes.set_xticks(df_diffs["threads"])
    axes.set_xlabel("Worker threads")
    axes.yaxis.set_major_formatter(mtick.PercentFormatter())
    fig.suptitle("Throughput differences")
    fig.savefig("tx_diff_percent.png", bbox_inches="tight", dpi=600)
