# Consumer migration

For a nixling consumer:

1. Add this flake as an input.
2. Import `homeManagerModules.default`.
3. Configure `programs.d2b-vuln-scanner.*`.
4. Choose desktop integration explicitly.
5. Activate through the consumer's normal NixOS/Home Manager workflow.

Rollback:

1. Disable the module or revert the flake input.
2. Disable related timers/services.
3. Restore any local compositor/bar snippets.
4. Run the consumer's activation command.
5. Optionally reset local state with `d2b-vuln-state reset --yes`.

