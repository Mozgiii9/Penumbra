#!/bin/bash

# Функция для отображения логотипа
display_logo() {
  echo -e '\e[40m\e[32m'
  echo -e '███╗   ██╗ ██████╗ ██████╗ ███████╗██████╗ ██╗   ██╗███╗   ██╗███╗   ██╗███████╗██████╗ '
  echo -e '████╗  ██║██╔═══██╗██╔══██╗██╔════╝██╔══██╗██║   ██║████╗  ██║████╗  ██║██╔════╝██╔══██╗'
  echo -e '██╔██╗ ██║██║   ██║██║  ██║█████╗  ██████╔╝██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██████╔╝'
  echo -e '██║╚██╗██║██║   ██║██║  ██║██╔══╝  ██╔══██╗██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██╔══██╗'
  echo -e '██║ ╚████║╚██████╔╝██████╔╝███████╗██║  ██║╚██████╔╝██║ ╚████║██║ ╚████║███████╗██║  ██║'
  echo -e '╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝'
  echo -e '\e[0m'
  echo -e "\nПодписаться на канал may.crypto{🦅} чтобы быть в курсе самых актуальных нод - https://t.me/maycrypto\n"
}

# Функция для отображения меню
show_menu() {
  echo "Выберите опцию:"
  echo "1. Установить ноду Penumbra"
  echo "2. Просмотреть логи ноды Penumbra"
  echo "3. Просмотреть список валидаторов"
  echo "4. Выйти из установочного скрипта"
}

# Функция для установки ноды Penumbra
install_penumbra() {
  read -p "Создайте имя для Вашей ноды: " NODE_NAME
  read -p "Введите IP-адрес сервера: " SERVER_IP

  sudo apt update && sudo apt upgrade -y
  apt install curl git make -y
  wget https://golang.org/dl/go1.21.4.linux-amd64.tar.gz
  tar -C /usr/local -xzf go1.21.4.linux-amd64.tar.gz
  export PATH=$PATH:/usr/local/go/bin
  go version
  curl --proto '=https' --tlsv1.2 -LsSf https://github.com/penumbra-zone/penumbra/releases/download/v0.78.0/pcli-installer.sh | sh
  source $HOME/.cargo/env
  pcli --version

  read -p "У Вас уже имеется кошелек в Penumbra? [да/нет] " WALLET_EXISTS
  if [[ "$WALLET_EXISTS" == "да" || "$WALLET_EXISTS" == "Да" ]]; then
    pcli init soft-kms import-phrase
  else
    pcli init soft-kms generate
  fi

  pcli view address

  read -p "Вы запросили тестовые токены в Discord'е Penumbra? Ответьте 'да' для продолжения. " TOKENS_REQUESTED
  if [[ "$TOKENS_REQUESTED" != "да" && "$TOKENS_REQUESTED" != "Да" ]]; then
    echo "Пожалуйста, запросите тестовые токены и повторите установку."
    exit 1
  fi

  pcli view sync
  pcli view balance
  curl -sSfL -O https://github.com/penumbra-zone/penumbra/releases/download/v0.78.0/pd-x86_64-unknown-linux-gnu.tar.gz
  tar -xf pd-x86_64-unknown-linux-gnu.tar.gz
  sudo mv pd-x86_64-unknown-linux-gnu/pd /usr/local/bin/
  pd --version

  echo export GOPATH="\$HOME/go" >> ~/.bash_profile
  echo export PATH="\$PATH:\$GOPATH/bin" >> ~/.bash_profile
  source ~/.bash_profile

  git clone --branch v0.37.5 https://github.com/cometbft/cometbft.git
  cd cometbft
  make install
  cometbft version
  cd

  pd testnet join --external-address $SERVER_IP:26656 --moniker $NODE_NAME

  sudo tee /etc/systemd/system/penumbra.service > /dev/null <<EOF
[Unit]
Description=Penumbra Node
After=network.target
[Service]
User=root
ExecStart=/usr/local/bin/pd start
Restart=always
RestartSec=3
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable penumbra
  systemctl start penumbra

  echo "Просмотр логов ноды Penumbra на протяжении 60 секунд..."
  timeout 60 journalctl -fu penumbra -n 50

  sudo tee /etc/systemd/system/cometbft.service > /dev/null <<EOF
[Unit]
Description=Cometbft Node
After=network.target
[Service]
User=root
ExecStart=/root/go/bin/cometbft start --home root/.penumbra/testnet_data/node0/cometbft
Restart=always
RestartSec=3
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable cometbft
  systemctl start cometbft

  grep -A3 pub_key ~/.penumbra/testnet_data/node0/cometbft/config/priv_validator_key.json

  pcli validator definition template \
      --tendermint-validator-keyfile ~/.penumbra/testnet_data/node0/cometbft/config/priv_validator_key.json \
      --file validator.toml

  sed -i '15s/.*/enabled = true/' validator.toml

  pcli validator definition upload --file validator.toml

  VALIDATOR_ADDRESS=$(pcli validator identity)

  for i in {1..90}
  do
    pcli tx delegate 1penumbra --to $VALIDATOR_ADDRESS
  done
}

# Функция для просмотра логов ноды Penumbra
view_logs() {
  echo "Через 15 секунд начнется отображение логов ноды Penumbra. Для возвращения в меню скрипта нажмите комбинацию клавиш CTRL+C"
  sleep 15
  journalctl -fu penumbra
}

# Функция для просмотра списка валидаторов
view_validators() {
  echo "Через 15 секунд начнется отображение списка валидаторов Penumbra. Вы можете найти своего валидатора там по адресу."
  sleep 15
  pcli query validator list --show-inactive
}

# Основной цикл меню
while true; do
  display_logo
  show_menu
  read -p "Введите номер опции: " option
  case $option in
    1)
      install_penumbra
      ;;
    2)
      view_logs
      ;;
    3)
      view_validators
      ;;
    4)
      echo "Выход из установочного скрипта."
      exit 0
      ;;
    *)
      echo "Неверный выбор. Пожалуйста, выберите опцию от 1 до 4."
      ;;
  esac
done
