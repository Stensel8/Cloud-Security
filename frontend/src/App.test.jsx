import { test, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import axios from 'axios';
import App from './App';

test('renders the product app navbar', () => {
  vi.spyOn(axios, 'get').mockResolvedValue({ data: [] });
  render(<App />);
  const brand = screen.getByText(/product app/i);
  expect(brand).toBeInTheDocument();
});
