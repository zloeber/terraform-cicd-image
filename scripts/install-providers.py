#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import subprocess
import sys
import tempfile

import click
import yaml


def run_command(
    command,
    cwd=None,
    silent=(os.getenv("DEBUG_ON", "false").lower() == "false"),
    exit_on_error=True,
):
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=cwd,
        shell=True,
    )
    cmdout, error = process.communicate()
    cmdout = cmdout.decode()
    error = error.decode()
    if error:
        if "Error" in error:
            click.echo(f"Command Error: {error}")
            if exit_on_error:
                sys.exit(1)
    if not silent:
        if cmdout:
            click.echo(f"Command Output: {cmdout}")
    return cmdout, error

@click.command()
@click.option('--config', default='config/provisioners.yml', help='Path to the YAML configuration file.')
def install_providers(config):
    try:
        with open(config, 'r') as file:
            data = yaml.safe_load(file)
    except FileNotFoundError:
        click.echo(f"Configuration file {config} not found.")
        return
    except yaml.YAMLError as exc:
        click.echo(f"Error parsing YAML file: {exc}")
        return
    except Exception as exc:
        click.echo(f"An error occurred: {exc}")
        return

    projects = data.get('projects', [])
    # Create a temporary directory to store the cloned repositories
    temp_dir = tempfile.TemporaryDirectory(
        delete=os.getenv("DEBUG_ON", "false").lower() == "false"
    )
    click.echo(f"Temporary directory created at {temp_dir.name}")
    for project in projects:
        name = project.get("name")
        local_path = project.get("path", None)
        click.echo(f"Processing project: {name}")
        if not isinstance(project, dict):
            click.echo(f"Skipping invalid project entry: {project}")
            continue
        if project.get('path', None) is not None:
            click.echo(f"Processing local path {local_path} for project: {name}")
            run_command("terraform init -backend=false", cwd=local_path)
        else:
            click.echo(f"Processing remote repository for project: {name}")
            if 'targets' not in project:
                targets = [
                    {
                        'branch': 'main',
                        'folder': '.',
                    }
                ]
            else:
                targets = project.get('targets')
            url = project.get('url', None)
            repo = url.split('/')[-1].replace('.git', '')
            click.echo(f"Repo path name: {repo}")
            if not url:
                click.echo(f"Skipping project with missing url: {name}")
                continue
            click.echo(f"Processing project: {name}")
            click.echo(f"Cloning repository {url}")
            repo_dir = os.path.join(temp_dir.name, repo)
            run_command(f"git clone {url} {repo_dir}")
            branch = 'main'
            for target in targets:
                target_branch = target.get('branch', 'main')
                folder = target.get('folder', '.')
                click.echo(f"Processing branch {branch} at folder {folder}")
                if target_branch != branch:
                    branch = target_branch
                    run_command(f"git checkout {branch}", cwd=repo_dir)
                terraform_dir = os.path.join(repo_dir, folder)
                run_command("terraform init -backend=false", cwd=terraform_dir)

if __name__ == '__main__':
    install_providers()