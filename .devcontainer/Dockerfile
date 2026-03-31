FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LANGUAGE=C.UTF-8

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        openssh-client \
        python3 \
        python3-pip \
        python3-venv \
        zsh \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir --break-system-packages \
    ansible \
    ansible-lint

RUN chsh -s /bin/zsh root

RUN RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    && printf '%s\n' \
        'export ZSH="$HOME/.oh-my-zsh"' \
        'ZSH_THEME="robbyrussell"' \
        'plugins=(git)' \
        '' \
        'source $ZSH/oh-my-zsh.sh' \
        > /root/.zshrc
