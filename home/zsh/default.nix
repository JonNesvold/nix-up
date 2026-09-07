{ pkgs, ... }:

{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      scan_timeout = 10;
      # Added $env_var at the start of the format to show the jail status
      format = "$env_var$username$hostname$directory$git_branch$git_state$git_status$python$nix_shell$kubectl$tofu\n$character";
      
      env_var.IN_JAIL = {
        variable = "IN_JAIL";
        # This format string ONLY renders if the variable is NOT empty
        format = "[🛡️ $variable]($style) ";
        style = "bold red";
      };

      directory = {
        truncate_to_repo = false;
        read_only = " ro";
        style = "#57C7FF";
      };
      character = {
        success_symbol = "[❯](#FF6AC1)";
        error_symbol = "[❯](#FF5C57)";
        vimcmd_symbol = "[❮](bright-green)";
      };
      git_branch = {
        format = "[$branch]($style)";
        symbol = "git ";
        style = "242";
      };
      git_status = {
        format = "[[(*$conflicted$untracked$modified$staged$renamed$deleted)](218) ($ahead_behind$stashed)]($style)";
        style = "cyan";
        conflicted = "​"; untracked = "​"; modified = "​"; staged = "​"; renamed = "​"; deleted = "​";
        stashed = "≡";
      };
      git_state = {
        format = ''\([$state( $progress_current/$progress_total)]($style)\) '';
        style = "bright-black";
      };
      cmd_duration = {
        format = "[$duration]($style) ";
        style = "yellow";
      };
      nix_shell = {
        symbol = "❄️ ";
        format = "[$symbol]($style)";
      };
      python = {
        format = "[$virtualenv]($style) ";
        style = "bright-black";
        symbol = "py ";
      };

      cmake.symbol = "cmake ";
      deno.symbol = "deno ";
      docker_context.symbol = "docker ";
      golang.symbol = "go ";
      lua.symbol = "lua ";
      nodejs.symbol = "nodejs ";
      rust.symbol = "rs ";
      sudo.symbol = "sudo ";
    };
  };

  home.packages = with pkgs; [
    zsh-completions
    nix-zsh-completions
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;

    "oh-my-zsh" = {
      enable = true;
      theme = "";
      extraConfig = ''
        zstyle :omz:plugins:ssh-agent identities id_ed25519
      '';
      plugins = [
        "git"
        "z"
        "vi-mode"
        "fzf"
        "ssh-agent"
      ];
    };

    profileExtra = ''
      if [ -f /etc/profile ]; then
        . /etc/profile
      fi
    '';

    initContent = ''
      if [ -f /etc/profile ]; then
        . /etc/profile
      fi
      if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi
      export PATH="$HOME/go/bin:$PATH"
      eval "$(direnv hook zsh)"

      # compile typst and open PDF
      tco() { typst compile "$1" && zathura "''${1%.typ}.pdf" & }

      # md → pdf via typst engine  
      mdpdf() { pandoc "$1" --pdf-engine=typst -o "''${1%.md}.pdf" }

      # docx → md (lawyers sending Word docs)
      docxmd() { pandoc "$1" -t markdown -o "''${1%.docx}.md" }

	  
      [[ -f ~/.config/forgejo/token ]] && export FORGEJO_TOKEN=$(cat ~/.config/forgejo/token)
    '';

    envExtra = ''
      export FZF_DEFAULT_OPTS=" \
      --color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 \
      --color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 \
      --color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796"
    '';

    shellAliases = {
      update = "sudo nixos-rebuild switch --flake";
      g = "git";
      gs = "git status";
      ga = "git add --all";
      gcm = "git commit -m";
      gch = "git checkout";
      gp = "git push";
      dotdot = "cd ..";
      n = "nvim";
      d = "docker";
      SS = "sudo systemctl";

      tc   = "typst compile";
      tw   = "typst compile --watch";

      topdf  = "pandoc --pdf-engine=typst -o";
      todocx = "pandoc -o";

      # JAIL ALIASES
      jail = "jail-dev";
      jail-nuke = "jail-dev && rm -rf .sandbox";

      l = "${pkgs.eza}/bin/eza -lh --icons=auto";
      ll = "${pkgs.eza}/bin/eza -lha --icons=auto --sort=name --group-directories-first";
      ls = "${pkgs.eza}/bin/eza -1 --icons=auto";
      tree = "${pkgs.eza}/bin/eza --icons=auto --tree";
      grep = "grep --color=always";
    };
  };
}
