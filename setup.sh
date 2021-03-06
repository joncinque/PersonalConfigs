#! /usr/bin/env bash

DIR=$(dirname "$0")
cd "$DIR"
FULLDIR=$(pwd)

INSTALL_GUI=false
INSTALL_EXTRA=false
RASPBERRY_PI=false
RELEASE=$(lsb_release -is)

echo "Base dev software"
echo "* Install base requirements"
sudo apt install -y curl git tmux

echo "* Install neovim"
sudo apt-add-repository -y ppa:neovim-ppa/stable
sudo apt install -y neovim

echo "* Install fish"
sudo apt-add-repository -y ppa:fish-shell/release-3
sudo apt install -y fish
chsh -s /usr/bin/fish

# Diff and setup each config
echo "Setting up all config files as symlinks"
for FILE in '.bashrc' '.gitconfig' '.gitignore_global' '.tmux.conf' '.inputrc'
do
  echo "Working on: $FILE"
  if [ -e ~/$FILE ]
  then
    echo "Existing file found, diff:"
    diff ~/$FILE "$FULLDIR"/$FILE
    rm -i ~/$FILE
  fi
  "* Setting up link to $FULLDIR/$FILE"
  ln -s "$FULLDIR"/$FILE ~
done
"* Setting up link to $FULLDIR/.ssh/config"
mkdir -p ~/.ssh
ln -s "$FULLDIR"/ssh_config ~/.ssh/config

"* Setting up link to $FULLDIR/init.vim"
mkdir -p ~/.config/nvim
ln -s "$FULLDIR"/init.vim ~/.config/nvim

"* Setting up link to $FULLDIR/config.fish"
mkdir -p ~/.config/fish
ln -s "$FULLDIR"/config.fish ~/.config/fish

"* Setting up link to $FULLDIR/flake8"
ln -s "$FULLDIR"/flake8 ~/.config

echo "* Setting up Plugged for vim plugins in init.vim"
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

echo "Coding software"
echo "* Install python dev requirements"
sudo apt install -y python3-dev python3-pip python3-venv

echo "* Install global ansible, pynvim, jedi, supervisor"
sudo pip3 install ansible pynvim jedi supervisor

echo "* Install node"
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt install -y nodejs

echo "* Install required npm packages for vim, typescript, reveal, and yarn"
sudo PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true npm install -g neovim typescript ts-node reveal-md yarn

echo "* Install nvim plugins"
cd ~
vim +PlugInstall

#vim -c 'CocInstall -sync coc-json coc-html coc-prettier coc-tsserver coc-eslint coc-pyright coc-rls coc-rust-analyzer|q'
# vim +UpdateRemotePlugins

echo "* Install Rust"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

echo "* Install rls and rust-analyzer"
~/.cargo/bin/rustup toolchain add nightly
~/.cargo/bin/rustup component add rust-src rust-analysis rls

echo "* Install bandwhich"
~/.cargo/bin/cargo install bandwhich

echo "* Install ruby and Jekyll for static pages"
sudo apt install -y ruby-dev build-essential zlib1g-dev
sudo gem install bundler

echo "* Setup supervisor"
echo_supervisord_conf | sudo tee /etc/supervisor/supervisord.conf
echo '[include]
files=conf.d/*.conf' | sudo tee -a /etc/supervisor/supervisord.conf
echo '[Unit]
Description=Supervisor daemon
Documentation=http://supervisord.org
After=network.target
[Service]
ExecStart=/usr/local/bin/supervisord -n -c /etc/supervisor/supervisord.conf
ExecStop=/usr/local/bin/supervisorctl $OPTIONS shutdown
ExecReload=/usr/local/bin/supervisorctl $OPTIONS reload
KillMode=process
Restart=on-failure
RestartSec=42s
[Install]
WantedBy=multi-user.target
Alias=supervisord.service' | sudo tee /etc/systemd/system/supervisord.service
sudo systemctl daemon-reload
sudo systemctl start supervisord

if [ "$RELEASE" = "Ubuntu" ]; then
  echo "* Install docker"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io
  sudo groupadd docker
  sudo usermod -aG docker $USER
  sudo systemctl restart docker.service
  # testing
  # docker run hello-world
fi

if [ "$INSTALL_EXTRA" = true ]; then
  echo "* Install dotnet core"
  wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
  sudo dpkg -i packages-microsoft-prod.deb
  sudo apt install -y dotnet-sdk-2.1

  echo "* Install mongodb 4.2"
  wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -
  echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
  sudo apt update
  sudo apt install -y mongodb-org

  echo "* Install influxdb"
  wget -qO- https://repos.influxdata.com/influxdb.key | sudo apt-key add -
  source /etc/lsb-release
  echo "deb https://repos.influxdata.com/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
  sudo apt update
  sudo apt install -y influxdb
  sudo systemctl start influxdb

  echo "* Install postgres"
  sudo apt install -y postgresql

  echo "* Install nginx"
  sudo add-apt-repository ppa:nginx/stable
  sudo apt install -y nginx

  # graphite + graphite api

  #echo "Install opam / ocaml"
  #sudo add-apt-repository ppa:avsm/ppa
  #sudo apt install opam
  # Setting up compiler and all
  # opam init

  #echo "Install meteor"
  #curl https://install.meteor.com/ | sh

  echo "Installing gcloud CLI" # https://cloud.google.com/sdk/gcloud/
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
  sudo apt update
  sudo apt install google-cloud-sdk
  gcloud init
  gcloud auth configure-docker
fi

if [ "$INSTALL_GUI" = true ]; then
  echo "GUI applications"
  echo "* Install meld (diffing), remmina (RDP to Windows), firefox"
  sudo apt install -y meld remmina firefox

  echo "* Install tixati"
  wget 'https://download2.tixati.com/download/tixati_2.83-1_amd64.deb'
  sudo dpkg -i tixati_2.83-1_amd64.deb

  echo "Non-programming applications"
  echo "* Install spotify"
  curl -sS 'https://download.spotify.com/debian/pubkey_0D811D58.gpg' | sudo apt-key add -
  echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
  sudo apt update
  sudo apt install spotify-client

  echo "* Install discord"
  wget 'https://discord.com/api/download?platform=linux&format=deb' -O discord.deb
  sudo dpkg -i discord.deb

  echo "* Install pandoc: check https://github.com/jgm/pandoc/releases for deb"
  echo "* Install texlive, pandoc requirement for pdf"
  sudo apt install texlive

  echo "* Install brave browser"
  curl -s https://brave-browser-apt-release.s3.brave.com/brave-core.asc | sudo apt-key --keyring /etc/apt/trusted.gpg.d/brave-browser-release.gpg add -
  echo "deb [arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
  sudo apt update
  sudo apt install brave-browser

  echo "* Install telegram"
  sudo apt install telegram-desktop

  echo "* Setup udev for ledger"
  wget -q -O - https://raw.githubusercontent.com/LedgerHQ/udev-rules/master/add_udev_rules.sh | sudo bash

  echo "* Install slack"
  echo "You will need to do this yourself, please confirm when this is done"
  read yay
fi

if [ "$RASPBERRY_PI" = true ]; then
  sudo pip3 install RPi.GPIO
fi

# WINDOWS ONLY
# steam
# visual studio
# windows terminal + keys and setups

# GitHub ssh token
# GITHUB_FILE=/home/jon/.ssh/github_id_rsa
# echo "$GITHUB_FILE" | ssh-keygen -t rsa -b 4096 -C "jon.cinque@gmail.com"
# echo "* Add public key to GitHub:"
# cat "$GITHUB_FILE".pub
