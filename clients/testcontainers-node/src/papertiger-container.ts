import { AbstractStartedContainer, GenericContainer, StartedTestContainer, Wait } from "testcontainers";

const PAPERTIGER_PORT = 12111;

export const DEFAULT_PAPERTIGER_IMAGE = "ghcr.io/neilberkman/paper_tiger:latest";

export type PaperTigerClockMode = "real" | "accelerated" | "manual";

export class StartedPaperTigerContainer extends AbstractStartedContainer {
  constructor(startedTestContainer: StartedTestContainer) {
    super(startedTestContainer);
  }

  getPort(): number {
    return this.getMappedPort(PAPERTIGER_PORT);
  }

  /**
   * The base URL to hand a Stripe SDK.
   *
   * @example
   * const stripe = new Stripe("sk_test_anything", {
   *   host: new URL(container.getApiBase()).hostname,
   *   port: container.getPort(),
   *   protocol: "http",
   * });
   */
  getApiBase(): string {
    return `http://${this.getHost()}:${this.getPort()}`;
  }

  /**
   * Advances the mock's clock. Requires `withClockMode("manual")`.
   *
   * Stripe's own test clocks allow three customers and three subscriptions each,
   * and advance at most two billing intervals per call. Neither limit applies here.
   */
  async advanceTime(options: { seconds: number } | { days: number }): Promise<void> {
    const body = "seconds" in options ? `seconds=${options.seconds}` : `days=${options.days}`;

    await this.request("/_config/time/advance", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body,
    });
  }

  /** Deletes every resource, so one container can be reused across tests. */
  async flush(): Promise<void> {
    await this.request("/_config/data", { method: "DELETE" });
  }

  private async request(path: string, init: RequestInit): Promise<Response> {
    const headers = new Headers(init.headers);
    headers.set("authorization", "Bearer sk_test_papertiger_testcontainers");

    const response = await fetch(`${this.getApiBase()}${path}`, { ...init, headers });

    if (!response.ok) {
      throw new Error(`PaperTiger ${path} failed: ${response.status} ${await response.text()}`);
    }

    return response;
  }
}

export class PaperTigerContainer extends GenericContainer {
  constructor(image: string = DEFAULT_PAPERTIGER_IMAGE) {
    super(image);

    this.withExposedPorts(PAPERTIGER_PORT)
      .withWaitStrategy(Wait.forHttp("/health", PAPERTIGER_PORT).forStatusCode(200))
      .withStartupTimeout(120_000);
  }

  /**
   * `"manual"` freezes the clock so tests drive it with `advanceTime`, `"accelerated"`
   * runs it at a multiplier, `"real"` follows the system clock. Defaults to `"real"`.
   */
  withClockMode(mode: PaperTigerClockMode, options: { multiplier?: number } = {}): this {
    this.withEnvironment({ PAPER_TIGER_CLOCK_MODE: mode });

    if (options.multiplier !== undefined) {
      this.withEnvironment({ PAPER_TIGER_CLOCK_MULTIPLIER: String(options.multiplier) });
    }

    return this;
  }

  /**
   * Advances subscriptions and finalizes invoices on a timer. Off by default,
   * because a timer races assertions in tests that drive the clock themselves.
   */
  withBillingEngine(): this {
    this.withEnvironment({ PAPER_TIGER_BILLING_ENGINE: "true" });
    return this;
  }

  override async start(): Promise<StartedPaperTigerContainer> {
    return new StartedPaperTigerContainer(await super.start());
  }
}
