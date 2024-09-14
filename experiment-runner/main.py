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


def build_cmd(binary_path: str, flags: Dict[str, Any]) -> str:
    flags_list = [binary_path]
    for k, v in flags.items():
        if type(v) is bool:
            if v:
                flags_list.append(f"--{k}=true")
            else:
                flags_list.append(f"--{k}=false")
        else:
            flags_list.append(f"--{k}={v}")
    return flags_list


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
        task_flags["csv_path"] = os.path.join(results_dir_name, f"{task_name}")

        cmd = build_cmd(experiment.binary_path, task_flags)
        print(" ".join(cmd))

        stdout_file_name = os.path.join(results_dir_name, f"{task_name}_stdout.txt")
        stderr_file_name = os.path.join(results_dir_name, f"{task_name}_stderr.txt")
        with (
            open(stdout_file_name, "w") as stdout,
            open(stderr_file_name, "w") as stderr,
        ):
            open("./leanstore", mode="w").close()
            subprocess.run(cmd, stdout=stdout, stderr=stderr)


if __name__ == "__main__":
    cwd = os.getcwd()
    directories = sys.argv[1:]
    print(directories)
    for directory in directories:
        os.chdir(directory)
        run_experiment()
        os.chdir(cwd)
