# yew starter

This is a basic yew application packaged using nix.
Instead of using the suggested solution, [trunk](https://github.com/thedodd/trunk), this repository uses [wasm-bindgen](https://github.com/rustwasm/wasm-bindgen) directly to build the wasm and javascript module.

For development convenience the nix flake exposes a single command (using [miniserve](https://github.com/svenstaro/miniserve)) which serves the `public` folder as well as the wasm bundle: `nix run .#serve`
