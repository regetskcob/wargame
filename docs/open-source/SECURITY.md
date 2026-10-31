# Security

Please report vulnerabilities by mail to review@panzergefecht.de instead of a
public issue. We answer as soon as we can; there is no bounty.

Clients are not trusted: rows are guarded by row level security, ratings go
through the RPC `record_round`, purchases through the edge function
`verify-purchase`. `plausibility.dart` is a sanity check, not an anti-cheat.
