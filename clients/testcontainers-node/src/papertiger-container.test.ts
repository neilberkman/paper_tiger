import Stripe from "stripe";
import { PaperTigerContainer } from "./papertiger-container";

const IMAGE = process.env.PAPERTIGER_IMAGE;

const stripeFor = (container: { getApiBase(): string; getPort(): number }) =>
  new Stripe("sk_test_papertiger", {
    host: new URL(container.getApiBase()).hostname,
    port: container.getPort(),
    protocol: "http",
  });

const newContainer = () => (IMAGE ? new PaperTigerContainer(IMAGE) : new PaperTigerContainer());

describe("PaperTigerContainer", { timeout: 240_000 }, () => {
  it("keeps state between requests", async () => {
    await using container = await newContainer().start();
    const stripe = stripeFor(container);

    const created = await stripe.customers.create({ email: "dev@example.com", name: "Devon" });
    const retrieved = await stripe.customers.retrieve(created.id);

    expect(retrieved.id).toBe(created.id);
  });

  it("advances time past what a Stripe test clock allows", async () => {
    await using container = await newContainer().withClockMode("manual").start();
    const stripe = stripeFor(container);

    const product = await stripe.products.create({ name: "Pro" });
    const price = await stripe.prices.create({
      product: product.id,
      unit_amount: 2000,
      currency: "usd",
      recurring: { interval: "month" },
    });

    // A Stripe test clock holds three customers and three subscriptions.
    for (let i = 0; i < 10; i++) {
      const customer = await stripe.customers.create({ email: `dev${i}@example.com` });
      await stripe.subscriptions.create({ customer: customer.id, items: [{ price: price.id }] });
    }

    await container.advanceTime({ days: 45 });

    const subscriptions = await stripe.subscriptions.list({ limit: 100 });
    expect(subscriptions.data).toHaveLength(10);
  });

  it("flushes data so one container can serve a suite", async () => {
    await using container = await newContainer().start();
    const stripe = stripeFor(container);

    await stripe.customers.create({ email: "temporary@example.com" });
    await container.flush();

    const customers = await stripe.customers.list();
    expect(customers.data).toHaveLength(0);
  });

  it("rejects a request with no API key", async () => {
    await using container = await newContainer().start();

    const response = await fetch(`${container.getApiBase()}/v1/customers`);

    expect(response.status).toBe(401);
  });

  it("accelerates the clock when asked", async () => {
    await using container = await newContainer().withClockMode("accelerated", { multiplier: 60 }).start();

    const response = await fetch(`${container.getApiBase()}/health`);

    expect(response.status).toBe(200);
  });
});
