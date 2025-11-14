from pathlib import Path
from typing import Optional

import grpc


def build_ssl_channel_credentials(
    root_cert_path: Optional[str],
    private_key_path: Optional[str],
    cert_chain_path: Optional[str],
) -> Optional[grpc.ChannelCredentials]:
    if not root_cert_path:
        return None

    root_cert = Path(root_cert_path).read_bytes()
    private_key = Path(private_key_path).read_bytes() if private_key_path else None
    cert_chain = Path(cert_chain_path).read_bytes() if cert_chain_path else None

    return grpc.ssl_channel_credentials(root_certificates=root_cert, private_key=private_key, certificate_chain=cert_chain)
