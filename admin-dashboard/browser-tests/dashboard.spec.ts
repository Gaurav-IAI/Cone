import { expect, test } from "@playwright/test";
test("signs in, navigates the dashboard, and submits validated participant fields", async ({
  page,
}) => {
  page.on("pageerror", (error) =>
    console.error("Browser runtime error:", error.message),
  );
  const uid = "test-superadmin";
  const email = "admin@example.org";
  const encode = (value: unknown) =>
    Buffer.from(JSON.stringify(value)).toString("base64url");
  const token = `${encode({ alg: "none", typ: "JWT" })}.${encode({ sub: uid, user_id: uid, email, email_verified: true, iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 3600, aud: "cone-test", iss: "https://securetoken.google.com/cone-test", auth_time: Math.floor(Date.now() / 1000), firebase: { sign_in_provider: "password" } })}.test`;
  await page.route("https://identitytoolkit.googleapis.com/**", (route) => {
    if (route.request().url().includes("accounts:lookup"))
      return route.fulfill({
        json: {
          users: [
            {
              localId: uid,
              email,
              emailVerified: true,
              passwordHash: "test",
              providerUserInfo: [
                { providerId: "password", email, federatedId: email },
              ],
            },
          ],
        },
      });
    return route.fulfill({
      json: {
        localId: uid,
        email,
        idToken: token,
        refreshToken: "test-refresh-token",
        expiresIn: "3600",
        registered: true,
      },
    });
  });
  const rows: Record<string, unknown>[] = [];
  await page.route("**/api/**", async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/me")
      return route.fulfill({
        json: {
          uid,
          email,
          fullName: "Test Administrator",
          role: "superadmin",
          conferenceId: "main",
          status: "active",
        },
      });
    if (url.pathname === "/api/overview")
      return route.fulfill({
        json: {
          registrations: 0,
          confirmed: 0,
          presenters: 0,
          mealsServed: 0,
          byRole: {
            presenter: 0,
            attendee: 0,
            speaker: 0,
            vip: 0,
            organiser: 0,
            volunteer: 0,
          },
          recentImports: [],
        },
      });
    if (url.pathname === "/api/records/participants") {
      if (route.request().method() === "POST") {
        const payload = route.request().postDataJSON();
        expect(payload.data.mobile).toBe("9876543210");
        expect(payload.data.fullName).toBe("Example Participant");
        rows.push({ id: payload.data.email, ...payload.data });
        return route.fulfill({ json: { id: payload.data.email } });
      }
      return route.fulfill({ json: { rows, next: null } });
    }
    return route.fulfill({ json: [] });
  });
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "Welcome back." }),
  ).toBeVisible();
  await page.getByLabel("Email address", { exact: true }).fill(email);
  await page
    .getByLabel("Password", { exact: true })
    .fill("password-for-browser-test");
  await page.getByRole("button", { name: "Sign in to workspace" }).click();
  await expect(
    page.getByRole("heading", { name: "Overview", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("Total registrations", { exact: true }),
  ).toBeVisible();
  await page.screenshot({
    path: "test-results/dashboard-desktop.png",
    fullPage: true,
  });
  await page.getByRole("button", { name: "Participants", exact: true }).click();
  await page
    .getByRole("button", { name: "Add participant", exact: true })
    .click();
  const dialog = page.getByRole("dialog");
  await dialog.getByLabel("Full name").fill("Example Participant");
  await dialog.getByLabel("Email address").fill("participant@example.org");
  await dialog.getByLabel("Mobile number").fill("9876543210");
  await dialog.getByLabel("Affiliation").fill("Example University");
  await dialog.getByRole("button", { name: "Save record" }).click();
  await expect(
    page.getByText("Example Participant", { exact: true }),
  ).toBeVisible();
  await page.setViewportSize({ width: 390, height: 844 });
  await page.getByRole("button", { name: "Toggle navigation" }).click();
  await expect(
    page.getByRole("button", { name: "Application settings", exact: true }),
  ).toBeVisible();
  await page.screenshot({
    path: "test-results/dashboard-mobile.png",
    fullPage: true,
  });
});
