import { test, expect } from '@playwright/test';

test('home page loads on desktop', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto('/');
  await expect(page).toHaveTitle(/./);
});

test('home page loads on mobile', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 812 });
  await page.goto('/');
  await expect(page.locator('body')).toBeVisible();
});
