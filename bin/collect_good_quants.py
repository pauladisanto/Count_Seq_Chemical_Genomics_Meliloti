#!/usr/bin/env python3

import glob
import shutil
import os
import argparse


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--project_dir", required=True)
    args = parser.parse_args()

    project_dir = os.path.abspath(args.project_dir)
    quants_dir = os.path.join(project_dir, "quants")
    output_dir = os.path.join(project_dir, "quants_merged")

    os.makedirs(output_dir, exist_ok=True)

    # Use recursive search (safer in case of nested folders)
    all_files = sorted(
        glob.glob(os.path.join(quants_dir, "**", "quant.sf"), recursive=True)
    )

    print(f"Found {len(all_files)} quant.sf files")

    if len(all_files) == 0:
        print("ERROR: No quant.sf files found")
        return

    for sf_file in all_files:
        parent_folder = os.path.basename(os.path.dirname(sf_file))
        dest = os.path.join(output_dir, f"{parent_folder}.sf")

        shutil.copy2(sf_file, dest)
        print(f"Copied {sf_file} -> {dest}")

    print("\nFinished: all quant.sf files collected.")


if __name__ == "__main__":
    main()