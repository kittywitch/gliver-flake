# gliver-flake

## Usage

If you set up your flake inputs a little something like this you should be able to use `nix flake update` as a mechanism for updating the underlying gliver ref, too. This should work, as long as the required dependencies for gliver do not change!

```nix
inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    gliver = {
      url = "git+https://codeberg.org/ebeem/gliver.git?ref=master";
      flake = false;
    };
    gliver-flake = {
        inputs = {
            nixpkgs.follows = "nixpkgs";
            gliver.follows = "gliver";
        };
    };
};
```

From there, within your configuration (assuming inputs is one of your specialArgs), within NixOS configuration you can do something like:

```nix
{ pkgs, inputs, ... }: {
    /* pretend there are things here! this is only an excerpt */
    environment.systemPackages = [
        inputs.gliver-flake.packages.${pkgs.stdenv.hostPlatform.system}.gliver
    ];
}
```

From there, `gliver` and `gliver-repl` should be available and a wayland-session should now be available within your display manager, if you have one. Happy hacking!

## Getting started with gliver!

If you have no prior guile experience, you should read [the Guile manual](https://doc.guix.gnu.org/guile/3.0.11/en/guile.html); it's an excellent resource!

Here's [an example configuration](https://codeberg.org/ebeem/gliver/src/branch/master/doc/examples/init.scm); it goes at your equivalent of `$XDG_CONFIG_HOME/gliver/init.scm`. If you don't know what that is, presume you should put it at `~/.config/gliver/init.scm`!

You should read [Default Keybindings](https://codeberg.org/ebeem/gliver/src/branch/master#headline-15) and make sure to take in how to use gliver's own features to see current keybindings and describe keys, variables and commands.

### Accessing the repl

You will likely want `pkgs.rlwrap` installed if you are using the Guile repl directly; otherwise if you are an emacs user, use Geiser to attach to gliver's repl and if you are a neovim user, use conjure to do so.

The REPL socket should be located at your equivalent of `$XDG_STATE_HOME/gliver/repl.sock`; if you don't know what that means, assume `~/.local/state/gliver/repl.sock`!

`rlwrap gliver-repl` should work sufficiently otherwise and knows where the repl is (at all times)!

### Keybinds

There are [three provided sets of keybindings](https://codeberg.org/ebeem/gliver/src/branch/master/gliver/contrib/keybindings) included with gliver. As of writing, the sway ones are kind of jank but provide a good basis for workspace handling.

If you change keybinds within your config, remember to add `(keybinding-sync!)` afterwards.


### Sway-like workspaces

This presumes you only have one display/output and would like 10 numerical workspaces produced on it. Should you desire something more complicated, hopefully this shows you a means for obtaining it at least in part. Note that this excerpt is incomplete, although the keybinds part is derived from the sway keybinding set, albeit with the manual range replaced with the use of the iota to repeat one's self less.

```scheme
(define numerical-workspaces (iota 10 1))

(let ((initial (resolve-workspace "workspace-1-1")))
  (when initial
    (workspace-name-set! initial "1")))
(for-each (lambda (i)
            (when (not (resolve-workspace (number->string i)))
              (workspace-create (number->string i)))
          ) (cdr numerical-workspaces))

; ... a gap for your other keybind setup ...

(for-each
  (lambda (i)
    (let* ((ws-str (number->string i))
           (key-str (if (= i 10) "0" ws-str)))
      (define-key *top-map* (string-append "s-" key-str)
                  (lambda () (workspace-focus-by-name ws-str)))
      (define-key *top-map* (string-append "s-S-" key-str)
                  (lambda () (window-workspace-move ws-str)))))
  numerical-workspaces)

(keybinding-sync!)
```

### Actions at startup with gliver

This is a little jank, but it works, frankly.

```scheme
(when (not (defined? 'setup-done))
  (workspace-focus-by-name "1")
  (exec "channel")
  (exec "awww-daemon")
  #f)
(define setup-done "meow")
```

### Input handling for laptops with `channel`

If you are using a laptop; you may wish to use `pkgs.river-channel` from nixpkgs to set touchpad options. Refer to [this codeberg issue](https://codeberg.org/ebeem/gliver/issues/43) for a means to allow channel to completely take over managing your input, should you wish to use it, while this issue is not yet closed.

Here is a relevant section of configuration for starting channel with gliver and preventing gliver from running its keybind reset hooks. The prior section is somewhat relevant here!

```scheme
(let* ((current-funcs (gliver-hook-functions *config-loaded-hook*))
       (cleaned (filter (lambda (i)
                          (not (string=? (symbol->string (car (cdr i)))
                                         "keyboard-on-config-loaded")))
                        current-funcs)))
  (set-gliver-hook-functions! *config-loaded-hook* cleaned))

(when (not (defined? 'setup-done))
  (exec "channel")
  #f)
(define setup-done "meow")
```

Also provided is an example `~/.config/river/config.rh`. I did not put it at `~/.config/channel/config.rh` because of [this codeberg issue](https://codeberg.org/Sivecano/channel/issues/25).

```
input {
    profiles {
        keyboard {
            keyboard {
                layout us, us
                options compose:rctrl,ctrl:nocaps
                repeat {
                    rate 25
                    delay 400
                }
            }
        }

        touchpad {
            pointer {
                scroll_factor 1.0
            }

            libinput {
                natural_scroll false
                scroll_method two_finger
                tap_to_click true
                click_method clickfinger
                accel_profile adaptive
                disable_while_typing false
            }
        }

    }

    rules [
        type, keyboard, keyboard
        name, * Touchpad, touchpad
    ]
}
```
