# ADR 0002: Remediation agent contract

Status: Accepted

Remediation agents are launched with argv vectors and receive a generated prompt
file through `{prompt_file}` substitution or documented stdin mode. Shell-string
agent configuration is rejected. Bundled skills are for downstream
vulnerability-fixing agents operating on scanner findings in consumer
repositories, not for maintaining this scanner repository.

