#!/usr/bin/env bash

# Script modified from https://raw.githubusercontent.com/mtbradley/brewski/master/mac-brewski.sh by Mark Bradley

# This code should manage several cases:
# OSX (Xcode command line tools required)
# Linux
# Windows system for linux

set -o errexit
set -o pipefail

if [ ! -w $(pwd) ]; then
  echo "Current directory $(pwd) is not writeable. Exiting."
  exit
fi

tectoplot_folder_dir=$HOME
miniconda_folder_dir=$HOME

# Function to output details of script.
function script_info() {
    cat <<EOF

Name:           install_tectoplot.sh
Description:    Automated installation of tectoplot + tectoplot-examples, +
                installation of dependencies using Homebrew or miniconda
Author:         Kyle Bradley
Tested:         MacOS Catalina, Mojave, Big Sur, Ubuntu Linux
Usage:          /usr/bin/env bash install_tectoplot.sh

1. Choose whether to install tectoplot and tectoplot-examples from Github
2.   If yes, select the directory to hold tectoplot/ and tectoplot-examples/
3.   After installation, choose to add tectoplot/ to your ~/.profile
4. Choose whether to install dependencies (homebrew, miniconda)
5.   If installing miniconda, choose the directory to hold miniconda/

EOF
}

function print_msg() {
  echo -e "${1}"
}

function report_storage() {
  local this_folder="${1}"
  echo
  kb_home=$(df -k $this_folder | sed '1d' | awk '{print $4/1024/1024}')
  print_msg "Disk containing directory $this_folder has ~${kb_home} Gb of storage remaining."
  echo
}

function check_tectoplot() {
  print_msg "\n"


  while true; do
    read -r -p "What tectoplot components should be installed [ tectoplot | examples | both | default=none ]   " response
    case $response in
      tectoplot)
        INSTALL_TECTOPLOT_REPO="true"
        INSTALL_TECTOPLOT_EXAMPLES="false"
        break
      ;;
      examples)
        INSTALL_TECTOPLOT_REPO="false"
        INSTALL_TECTOPLOT_EXAMPLES="true"
        break
      ;;
      both)
        INSTALL_TECTOPLOT_REPO="true"
        INSTALL_TECTOPLOT_EXAMPLES="true"
        break
      ;;
      none|"")
        break
      ;;
    esac
  done

  if [[ ${INSTALL_TECTOPLOT_REPO} =~ "true" || ${INSTALL_TECTOPLOT_EXAMPLES} =~ "true" ]]; then

    while true; do
      print_msg "\n"
      read -r -p "Enter installation directory for repositories: [ default=${tectoplot_folder_dir} | path | none ]   " response
      case $response in
        "")
          echo
          if [[ ! -d $tectoplot_folder_dir ]]; then
            print_msg "Directory $tectoplot_folder_dir does not exist. Not installing tectoplot."
            INSTALL_TECTOPLOT="false"
          else
            if [[ -d ${tectoplot_folder_dir}/tectoplot/ ]]; then
              print_msg "WARNING: tectoplot folder ${tectoplot_folder_dir}/tectoplot/ already exists!"
              print_msg "Not installing over existing folder."
              INSTALL_TECTOPLOT="false"
            fi
            print_msg "Installing tectoplot into default directory ${tectoplot_folder_dir}/tectoplot/"
            INSTALL_TECTOPLOT="true"
          fi
          break
        ;;
        none)
          echo
          print_msg "Not installing tectoplot!"
          INSTALL_TECTOPLOT="false"
          break
        ;;
        *)
          echo
          if [[ ! -d $response ]]; then
            print_msg "Installation directory $response does not exist. Creating folder."
            mkdir -p "$response"
            tectoplot_folder_dir=$response
            INSTALL_TECTOPLOT=true
          else
            if [[ -d ${response}/tectoplot/ ]]; then
              print_msg "WARNING: tectoplot folder ${response}/tectoplot/ already exists!"
              print_msg "Not installing over existing folder."
              INSTALL_TECTOPLOT="false"
            fi
            tectoplot_folder_dir=$response
            INSTALL_TECTOPLOT="true"
          fi
          break
        ;;
      esac
    done
  fi
}

function set_miniconda_folder() {
  print_msg "Default installation directory for miniconda: ${miniconda_folder_dir}/miniconda/"
  while true; do
    read -r -p "Enter alternative installation directory for miniconda/ (e.g. ${miniconda_folder_dir}/): [enter for default]   " response
    case $response in
      "")
        print_msg "Using default miniconda folder: $miniconda_folder_dir/miniconda/"
        break
      ;;
      *)
      if [[ ! -d $response ]]; then
        print_msg "Miniconda installation folder ${response} does not exist."
        exit 1
      else
        if [[ -d ${response}/miniconda/ ]]; then
          print_msg "WARNING: miniconda folder ${response}/miniconda/ already exists!"
        fi
        miniconda_folder_dir=$response
      fi
      break
      ;;
    esac
  done
  print_msg "Note: A miniconda installation of tectoplot requires ~3.2 Gb of storage space. "
}

# Function to pause script and check if the user wishes to continue.
function check_dependencies() {
  local response
  print_msg "\n"
  while true; do
    read -r -p "How do you want to install tectoplot's dependencies? [ homebrew | miniconda | default=none ]   " response
    case "${response}" in
    homebrew)
      echo
      INSTALLTYPE="homebrew"
      print_msg "Assuming Homebrew Cellar will install onto disk holding directory $HOME..."
      report_storage $HOME
      break
      ;;
    miniconda)
      echo
      INSTALLTYPE="miniconda"
      break
      ;;
    none|"")
      echo
      break
      ;;
    *)
      echo
      print_msg "No option selected for dependency installation: exiting."
      exit
      ;;
    esac
  done
}

function query_setup_tectoplot() {
  local response
  print_msg "\n"
  while true; do
    read -r -p "Add tectoplot's path to your ~/.profile? [Yy]/n  " response
    case "${response}" in
    Y|y|"")
      echo
      SETUP_TECTOPLOT="true"
      break
      ;;
    n)
      echo
      SETUP_TECTOPLOT="false"
      break
      ;;
    *)
      echo
      SETUP_TECTOPLOT="false"
      break
      ;;
    esac
  done
}

# Function check command exists
function command_exists() {
  command -v "${@}" >/dev/null 2>&1
}

function check_xcode() {
  print_msg "Checking for setup dependencies..."
  print_msg "Checking for Xcode command line tools..."
  if command -v xcode-select --version >/dev/null 2>&1; then
    print_msg "Xcode command line tools are installed."
  else
    print_msg "\n"
    print_msg "Attempting to install Xcode command line tools..."
    if xcode-select --install  >/dev/null 2>&1; then
        print_msg "Re-run script after Xcode command line tools have finished installing.\n"
    else
        print_msg "Xcode command line tools install failed.\n"
    fi
    exit 1
  fi
}

function install_homebrew() {
  print_msg "\nInstalling Homebrew..."
  print_msg "Checking for Homebrew..."
  if command_exists "brew"; then
    print_msg "Homebrew is installed."

    # Is there really any reason to update/upgrade? As they take significant
    # time to complete.

    if [[ $UPDATEFLAG -eq 1 ]]; then
      print_msg "Running brew update..."
      if brew update ; then
        print_msg "Brew update completed."
      else
        print_msg "Brew update failed."
      fi
    fi
    if [[ $UPGRADEFLAG -eq 1 ]]; then
      print_msg "Running brew upgrade..."
      if brew upgrade; then
        print_msg "Brew upgrade completed."
      else
        print_msg "Brew upgrade failed."
      fi
    fi
  else
    print_msg "\n"
    print_msg "Homebrew not installed. Attempting to install via curl..."
    if command_exists "curl"; then
      if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        print_msg "Homebrew was installed.\n"
      else
        print_msg "Homebrew install failed.\n"
        exit 1
      fi
    else
      print_msg "curl not installed... cannot install Homebrew."
      exit 1
    fi
  fi
}

function brew_packages() {
  # addition taps to enable packages not included in core tap
  tap_list=""
  # term_list includes packages which run from terminal without GUI
  term_list="git gawk proj gcc gmt@6 ghostscript"
  # cask_list includes packages macOS apps, fonts and plugins and other non-open source software
  cask_list=""
  # print_msg "\nAdding additional Homebrew taps..."
  for tap in ${tap_list}; do
    print_msg "Checking for tap > ${tap}"
    if brew tap | grep "${tap}" >/dev/null 2>&1 || command_exists "${tap}"; then
      print_msg "Tap ${tap} already added."
    else
      print_msg "\n"
      print_msg"Attempting to add tap ${tap}..."
      if brew tap "${tap}"; then
        print_msg "Tap ${tap} added.\n"
      else
        print_msg "Unable to add tap ${tap}.\n"
      fi
    fi
  done
  # print_msg "\nInstalling brew core packages..."
  for pkg in ${term_list}; do
    print_msg "Checking for package > ${pkg}"
    if brew list "${pkg}" >/dev/null 2>&1 || command_exists "${pkg}"; then
      print_msg "Package ${pkg} already installed."
    else
      print_msg "\n"
      print_msg "Attempting to install ${pkg}..."
      if brew install "${pkg}"; then
        print_msg "Package ${pkg} installed.\n"
      else
        print_msg "Package ${pkg} install failed.\n"
      fi
    fi
  done
  # print_msg "\nInstalling brew cask packages..."
  for cask in ${cask_list}; do
    print_msg "Checking for cask package > ${cask}"
    if brew list --cask "${cask}" >/dev/null 2>&1; then
      print_msg "Package ${cask} already installed."
    else
      print_msg "\n"
      print_msg "Attempting to install ${cask}..."
      if brew install --cask "${cask}"; then
          print_msg "Package ${cask} installed.\n"
      else
          print_msg "Package ${cask} install failed.\n"
      fi
    fi
  done
}

function exit_msg() {
  echo "Previous step failed... exiting"
  exit 1
}

function install_miniconda() {
  if [[ -d "${HOME}"/miniconda ]]; then
    print_msg "Miniconda already installed? ${HOME}/miniconda/ already exists."
  else
    case "$OSTYPE" in
      linux*)
        print_msg "Detected linux... assuming x86_64"
        curl https://repo.anaconda.com/miniconda/Miniconda2-latest-Linux-x86_64.sh > miniconda.sh
        ;;
      darwin*)
        print_msg "Detected OSX... assuming x86_64"
        curl https://repo.anaconda.com/miniconda/Miniconda2-latest-MacOSX-x86_64.sh >  miniconda.sh
      ;;
    esac
    if [[ -s ./miniconda.sh ]]; then
      print_msg "Executing miniconda installation script..."
      bash ./miniconda.sh -b -p $HOME/miniconda
    else
      print_msg "Could not execute miniconda.sh... exiting"
      exit 1
    fi
  fi
}

function miniconda_deps() {
  if [[ -x "${HOME}"/miniconda/bin/conda ]]; then
    source "${HOME}/miniconda/etc/profile.d/conda.sh"
    echo "Running conda hook..."
    eval $("${HOME}"/miniconda/bin/conda shell.bash hook)

    print_msg "Updating conda..."

    conda update -n base -c defaults conda

    print_msg "Activating conda..."
    conda activate || exit_msg

    print_msg "Initializing conda to use bash..."
    conda init bash || exit_msg

    print_msg "Creating tectoplot environment..."
    conda create --name tectoplot || exit_msg

    print_msg "Activating tectoplot environment..."
    conda activate tectoplot || exit_msg

    print_msg "Installing dependencies into new tectoplot environment..."
    conda install python=3.9 git gmt gawk ghostscript -c conda-forge

    case "$OSTYPE" in
      linux*)
        print_msg "Detected linux... assuming x86_64"
        conda install gcc_linux-64 gxx_linux-64 gfortran_linux-64 -c conda-forge
        ;;
      darwin*)
        print_msg "Detected OSX... assuming x86_64"
        conda install clang_osx-64 clangxx_osx-64 gfortran_linux-64 -c conda-forge
      ;;
    esac

    print_msg "After installation, from the command line run this command to"
    print_msg "use the installed tectoplot environment:"
    print_msg "conda activate tectoplot"
  else
    print_msg "Cannot call miniconda from ./miniconda/bin/conda. Exiting"
    exit 1
  fi
}

function clone_tectoplot() {
  if [[ $DO_INSTALL_TECTOPLOT =~ "true" ]]; then
    if [[ -d ${tectoplot_folder_dir}/tectoplot/ ]]; then
      print_msg "Folder ./tectoplot already exists... not cloning"
    else
      if git clone https://github.com/kyleedwardbradley/tectoplot.git ${tectoplot_folder_dir}/tectoplot; then
        print_msg "tectoplot git repository cloned to ${tectoplot_folder_dir}/tectoplot"
      else
        print_msg "Could not clone tectoplot repository to ${tectoplot_folder_dir}/tectoplot"
      fi
    fi
  fi
}

function clone_tectoplot_examples() {
  if [[ -d ${tectoplot_folder_dir}/tectoplot-examples/ ]]; then
    print_msg "Folder ./tectoplot already exists... not cloning repository"
  else
    if git clone https://github.com/kyleedwardbradley/tectoplot-examples ${tectoplot_folder_dir}/tectoplot-examples; then
      print_msg "tectoplot-examples git repository cloned to ${tectoplot_folder_dir}/tectoplot-examples"
    else
      print_msg "Could not clone tectoplot examples repository to ${tectoplot_folder_dir}/tectoplot-examples"
    fi
  fi
}

# One function to rule them all.
main() {
  clear
  script_info

  check_tectoplot

  DO_INSTALL_TECTOPLOT="false"
  report_storage $tectoplot_folder_dir

  while true; do
    read -r -p "Install selected repositories? [ default=y | n ]  " response
    case "${response}" in
    Y|y|"")
      echo
      DO_INSTALL_TECTOPLOT="true"
      break
      ;;
    n)
      echo
      DO_INSTALL_TECTOPLOT="false"
      break
      ;;
    *)
      echo
      print_msg "Unrecognized input ${response}. Not installing."
      DO_INSTALL_TECTOPLOT="false"
      break
      ;;
    esac
  done

  if [[ $DO_INSTALL_TECTOPLOT =~ "true" ]]; then

    if [[ $INSTALL_TECTOPLOT_REPO =~ "true" ]]; then
      clone_tectoplot
      query_setup_tectoplot
    fi

    if [[ $INSTALL_TECTOPLOT_EXAMPLES =~ "true" ]]; then
      clone_tectoplot_examples
    fi
  fi

  check_dependencies


  case $INSTALLTYPE in
    homebrew)
      check_xcode
      install_homebrew
      brew_packages
    ;;
    miniconda)
      set_miniconda_folder
      report_storage $miniconda_folder_dir
      install_miniconda
      miniconda_deps
    ;;
  esac


  if [[ $INSTALL_TECTOPLOT_REPO =~ "true" && $SETUP_TECTOPLOT =~ "true" ]]; then
    if [[ -d ${tectoplot_folder_dir}/tectoplot/ ]]; then

      print_msg "Setting up tectoplot..."

      cd ${tectoplot_folder_dir}/tectoplot/
      print_msg "tectoplot -addpath"

      ./tectoplot -addpath
      source ~/.profile
      cd -

      while true; do
        read -r -p "Path to tectoplot data folder: [ default=${HOME}TectoplotData/ | path | none ] " response
        case "${response}" in
        "")
          echo
          ${tectoplot_folder_dir}/tectoplot -setdatadir "${HOME}TectoplotData/"
          break
          ;;
        none)
          echo
          break
          ;;
        *)
          echo
          ${tectoplot_folder_dir}/tectoplot -setdatadir "${response}/"
          break
          ;;
        esac
      done

    fi
  fi

  print_msg "Script completed.\n"
}

main "${@}"
