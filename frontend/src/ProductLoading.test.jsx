import { afterEach, describe, expect, test, vi } from 'vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import axios from 'axios';
import App from './App';

const product = { id: 1, title: 'Test product', price: 12.34, quantity: 2 };

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  window.history.replaceState({}, '', '/');
});

describe.each(['/1', '/1/edit'])('loading product at %s', (path) => {
  function openPage() {
    window.history.replaceState({}, '', path);
    render(<App />);
  }

  test('shows NotFound for an HTTP 404', async () => {
    vi.spyOn(axios, 'get').mockRejectedValue({ response: { status: 404 } });
    openPage();
    expect(await screen.findByText('Page not found')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Try again' })).not.toBeInTheDocument();
  });

  test.each([
    ['server failure', { response: { status: 500, data: { message: 'Server unavailable' } } }],
    ['network failure', new Error('Network Error')],
  ])('shows a retryable error for a %s', async (_name, failure) => {
    vi.spyOn(axios, 'get').mockRejectedValue(failure);
    openPage();
    expect(await screen.findByRole('alert')).toHaveTextContent('Could not load the product.');
    expect(screen.queryByText('Page not found')).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /^(Update|Delete)$/ })).not.toBeInTheDocument();
  });

  test('can retry successfully after a temporary failure', async () => {
    const get = vi.spyOn(axios, 'get')
      .mockRejectedValueOnce({ response: { status: 503 } })
      .mockResolvedValueOnce({ data: product });
    openPage();
    fireEvent.click(await screen.findByRole('button', { name: 'Try again' }));
    if (path.endsWith('/edit')) {
      expect(await screen.findByDisplayValue(product.title)).toBeInTheDocument();
    } else {
      expect(await screen.findByText(product.title)).toBeInTheDocument();
    }
    expect(get).toHaveBeenCalledTimes(2);
    expect(get.mock.calls[1][0]).toBe(get.mock.calls[0][0]);
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  });
});
