# scripts
A repo containing all bash scripts I use on my Mac.

## Pre-requisites:

- Git: 

## Installation

To install the scripts, run the following command:

```bash
git clone https://github.com/BirjuVachhani/scripts.git $HOME/.scripts && $HOME/.scripts/install.sh
```

Or using curl to download and execute the install script directly:

```bash
curl -fsSL https://raw.githubusercontent.com/BirjuVachhani/scripts/refs/heads/main/install.sh | bash -s -- $HOME/.scripts
```

This will:
- Clone/download the repository to `$HOME/.scripts`
- Add the scripts directory to your PATH
- Make the scripts available in your terminal

After installation, restart your terminal or run `source ~/.zshrc` (or `source ~/.bashrc` for bash) to use the scripts.

### Installing from your own fork

If you have forked this repository, then you can install if with this command by replacing `<YOUR_USERNAME>` with your Github User Name.

```bash
git clone https://github.com/<YOUR_USERNAME>/scripts.git $HOME/.scripts && $HOME/.scripts/install.sh
```

Or using curl to download and execute the install script directly. Replace `<YOUR_USERNAME>` with your Github User Name.

```bash
curl -fsSL https://raw.githubusercontent.com/BirjuVachhani/scripts/refs/heads/main/install.sh | bash -s -- $HOME/.scripts
```

## Adding your own custom scripts

If you want to add your own custom scripts then follow these steps:

1. Fork this repository:
2. Use [Installing from your own fork](#installing-from-your-own-fork) guide to install it on your Machine.
3. Create `$HOME/.scripts/custom` directory and add your scripts to this directory. It will automatically be added to your path.
4. You can use git to push this to your own fork to use it across devices.

## Adding your own Local scripts:

If you need to add your own scripts that needs to stay locally on that system only then do the following: 

- Create 'local' directory inside `$HOME/.scripts/` directory.
- Add your script files there. They will automatically be available in your PATH. These files will stay local to your machine.


# License

```
BSD 3-Clause License

Copyright (c) 2025, Birju Vachhani

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

```
