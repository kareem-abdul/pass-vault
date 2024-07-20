#!/usr/bin/env bash

# pass vault - Password Store Extension (https://www.passwordstore.org/)
# Copyright (C) 2024 Abdul Kareem <abdul.k+git@gmail.com>.

shopt -s extglob

cmd_vault_usage() {
    cat <<_vault_usage
Usage:
$PROGRAM vault COMMAND 
COMMANDS:
    init
    open
    close
_vault_usage
    exit 0
}

PASSWORD_STORE_VAULT_DIR=".vault"
PASSWORD_STORE_VAULT_NAME="password-store.vault.img"
PASSWORD_STORE_DEBUG=false
PASSWORD_STORE_VAULT_ID_FILE="id"

die() { echo "$*" 1>&2 ; exit 1; }

info() {
    echo "info: $@" >&2
}

debug() {
    $PASSWORD_STORE_DEBUG && echo "debug: $@" >&2
}

password_home() {
    if [ -z $PASSWORD_STORE_DIR ]; then
        echo "$HOME/.password-store"
        exit 0
    fi
    echo $PASSWORD_STORE_DIR
}

vault_id() {
    local vault_id_file="$(password_home)/$PASSWORD_STORE_VAULT_DIR/$PASSWORD_STORE_VAULT_ID_FILE"
    local id=0
    if [ -f $vault_id_file ]; then
        id=$(cat $vault_id_file)
    else
        id="vault.$(uuidgen)"
    fi
    debug "vault id generated as $id"
    echo $id
}


cmd_vault_open() {
    info "Opening vault"
    debug "Operating on $(password_home)"


    cd $(password_home)
    local VAULT_HOME="$PASSWORD_STORE_VAULT_DIR"
    local VAULT_FILE="${VAULT_HOME}/$PASSWORD_STORE_VAULT_NAME"

    if [ ! -d $VAULT_HOME ]; then
        die "Vault not initialized. Do a $PORGRAM vault init."
    fi

    local VAULT_ID=$(vault_id)
    sudo cryptsetup open --type luks $VAULT_FILE $VAULT_ID
    cd ..
    sudo mount /dev/mapper/$VAULT_ID $(password_home)
    cd $(password_home)
    echo "$VAULT_ID" > "$VAULT_HOME/$PASSWORD_STORE_VAULT_ID_FILE"
    debug "Vault opened as $VAULT_ID"
}

cmd_vault_close() {
    debug "Operating on $(password_home)"
    local VAULT_HOME="$(password_home)/$PASSWORD_STORE_VAULT_DIR"
    local VAULT_FILE="${VAULT_HOME}/$PASSWORD_STORE_VAULT_NAME"

    if [ ! -d $VAULT_HOME ]; then
        die "Vault not open or initialized"
    fi

    local VAULT_ID=$(vault_id)
    rm $VAULT_HOME/$PASSWORD_STORE_VAULT_ID_FILE
    sudo umount /dev/mapper/$VAULT_ID
    sudo cryptsetup close /dev/mapper/$VAULT_ID

    info "Clossing vault $(vault_id)"
}

cmd_vault_init() {
    info "Initializing luks vault"
    debug "Operating on $(password_home)"
    cd $(password_home)

    local VAULT_HOME="$PASSWORD_STORE_VAULT_DIR"
    local VAULT_FILE="${VAULT_HOME}/$PASSWORD_STORE_VAULT_NAME"
    local VAULT_ID=$(vault_id)

    if [ -d $VAULT_HOME ]; then
        return 0
    fi
    umask 077
    mkdir $VAULT_HOME
    touch $VAULT_FILE
    info "Creating vault"
    fallocate -l 30M $VAULT_FILE
    cryptsetup luksFormat $VAULT_FILE
    info "Opening vault $VAULT_FILE with id $VAULT_ID"
    sudo cryptsetup open --type luks $VAULT_FILE "$VAULT_ID"
    info "Creating FS"
    sudo mkfs.ext4 -L vault -m 0 /dev/mapper/$VAULT_ID
    info "Mounting vault"
    mkdir /tmp/$VAULT_ID
    sudo mount /dev/mapper/$VAULT_ID /tmp/$VAULT_ID
    info "Moving passwords to vault $VAULT_ID"
    sudo chown -R $USER:$USER /tmp/$VAULT_ID
    mv $(password_home)/{.,}!(vault|extensions) /tmp/$VAULT_ID
    cp -R .extensions /tmp/$VAULT_ID
    mkdir /tmp/$VAULT_ID/$VAULT_HOME
    echo "$VAULT_ID" > /tmp/$VAULT_ID/$VAULT_HOME/$PASSWORD_STORE_VAULT_ID_FILE

    if [ -d "/tmp/$VAULT_ID/lost+found" ]; then
        rm -rf /tmp/$VAULT_ID/lost+found
    fi

    sudo umount /dev/mapper/$VAULT_ID
    info "closing pass vault"
    sudo cryptsetup close /dev/mapper/$VAULT_ID
    rm -rf /tmp/$VAULT_ID
}

cmd_vault() {
    case "$1" in
        help|-h|--help) shift; cmd_vault_usage "$@" ;;
        init)           shift; cmd_vault_init "$@" ;;
        open)           shift; cmd_vault_open "$@" ;;
        close)          shift; cmd_vault_close "$@" ;;
        *)              die "Error: Invalid command $1. $PROGRAM vault --help to see available commands"
    esac
}

cmd_vault "$@"
