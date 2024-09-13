import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, Self
from pydantic import BaseModel

import yaml


class TPCCArgs(BaseModel):
    flags: Dict[str, Any]


class TPCCExperiment(BaseModel):
    binary_path: str
    repetitions: int
    flags: Dict[str, Any]
    tasks: Dict[str, TPCCArgs]


def build_flags(flags: Dict[str, Any], csv_path: str) -> str:
    flats_list = [f"--{k}={v}" for k, v in flags.items()]
    flats_list.append(f"--csv_path={csv_path}")
    return " ".join(flats_list)


def run_experiment(
    config_file_name: str = "config.yaml",
    results_dir_name: str = "results",
):
    with open(config_file_name, "r") as file:
        config_data = yaml.safe_load(file)

    experiment = TPCCExperiment(**config_data)
    if not os.path.isdir(results_dir_name):
        os.mkdir(results_dir_name)

    for task_name, task_args in experiment.tasks.items():
        task_flags = experiment.flags.copy()
        task_flags.update(task_args.flags)

        cmd_flags = build_flags(
            task_flags, os.path.join(results_dir_name, f"{task_name}")
        )
        cmd = f"{experiment.binary_path} {cmd_flags}"

        stdout_file_name = os.path.join(results_dir_name, f"{task_name}_stdout.txt")
        stderr_file_name = os.path.join(results_dir_name, f"{task_name}_stderr.txt")
        with (
            open(stdout_file_name, "w") as stdout,
            open(stderr_file_name, "w") as stderr,
        ):
            open("./leanstore", mode='w').close()
            subprocess.run(cmd, shell=True, stdout=stdout, stderr=stderr)


if __name__ == "__main__":
    cwd = os.getcwd()
    directories = sys.argv[1:]
    print(directories)
    for directory in directories:
        os.chdir(directory)
        run_experiment()
        os.chdir(cwd)
