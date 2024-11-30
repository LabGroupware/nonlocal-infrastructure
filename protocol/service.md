## Service

### 公開したいサービス
VirtualServiceを`istio-system`内で作成し, gatewayは`public-gateway`に指定する.

### 管理者用サービス(State)
- `[Kiali](https://kiali.state.api.cresplanex.org)`: Istioメッシュの視覚化
- `[Grafana](https://grafana.state.api.cresplanex.org)`: メトリクス監視
- `[Jaeger](https://jaeger.state.api.cresplanex.org)`: 分散トレース監視

### 管理者用サービス(Event)
- `[Kiali](https://kiali.event.api.cresplanex.org)`: Istioメッシュの視覚化
- `[Grafana](https://grafana.event.api.cresplanex.org)`: メトリクス監視
- `[Jaeger](https://jaeger.event.api.cresplanex.org)`: 分散トレース監視

### Kiali権限
[参照先](https://pre-v1-41.kiali.io/documentation/v1.41/configuration/rbac/)
