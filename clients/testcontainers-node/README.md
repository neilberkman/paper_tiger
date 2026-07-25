# @neilberkman/papertiger-testcontainers

A [Testcontainers](https://node.testcontainers.org) module for
[PaperTiger](https://github.com/neilberkman/paper_tiger), a stateful mock Stripe server.

Every test, suite, or CI job gets its own isolated Stripe API on a throwaway container. State
persists within a container, so a customer created in one request comes back in the next, and
nothing is shared between containers, so parallel jobs cannot collide.

```bash
npm install @neilberkman/papertiger-testcontainers --save-dev
```

## Usage

```ts
import Stripe from "stripe";
import { PaperTigerContainer } from "@neilberkman/papertiger-testcontainers";

const container = await new PaperTigerContainer().start();

const stripe = new Stripe("sk_test_anything", {
  host: new URL(container.getApiBase()).hostname,
  port: container.getPort(),
  protocol: "http",
});

const customer = await stripe.customers.create({ email: "dev@example.com" });
await stripe.customers.retrieve(customer.id); // still there

await container.stop();
```

Any non-empty API key is accepted. The mock does no real authentication, but it does require the
header, as Stripe does.

## Time travel

Stripe's test clocks hold [three customers, three subscriptions, and ten quotes each](https://docs.stripe.com/billing/testing/test-clocks/api-advanced-usage),
and advance at most two billing intervals per call. Neither limit applies here.

```ts
const container = await new PaperTigerContainer().withClockMode("manual").start();

// ...create as many customers and subscriptions as the test needs...

await container.advanceTime({ days: 45 });
```

## Reference

### `PaperTigerContainer`

| Method | Description |
| --- | --- |
| `new PaperTigerContainer(image?)` | Defaults to `ghcr.io/neilberkman/paper_tiger:latest`. Pin a tag in CI. |
| `withClockMode(mode, options?)` | `"real"`, `"accelerated"`, or `"manual"`. Pass `{ multiplier }` with `"accelerated"`. |
| `withBillingEngine()` | Advances subscriptions and finalizes invoices on a timer. Off by default, since a timer races tests that drive the clock themselves. |

Everything on [`GenericContainer`](https://node.testcontainers.org/features/containers/) is
available too, including `withNetwork`, `withLabels`, and `withReuse`.

### `StartedPaperTigerContainer`

| Method | Description |
| --- | --- |
| `getApiBase()` | Base URL to give the Stripe SDK. |
| `getPort()` | Mapped host port. |
| `advanceTime({ seconds })` / `advanceTime({ days })` | Advances the clock. Requires `withClockMode("manual")`. |
| `flush()` | Deletes every resource, so one container can serve a whole suite. |

## Without Testcontainers

The image is a plain container and needs nothing from this package:

```bash
docker run -p 12111:12111 ghcr.io/neilberkman/paper_tiger
```

Port 12111 is stripe-mock's default, so an existing stripe-mock service definition can be
repointed without changing anything else.

## License

MIT
