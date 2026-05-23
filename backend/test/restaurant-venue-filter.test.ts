import { describe, expect, it } from 'vitest';
import {
  isRestaurantCuisineLabel,
  isRestaurantVenue,
} from '../src/modules/restaurants/restaurant-venue-filter.js';

describe('restaurant venue filter', () => {
  it('accepts typical restaurant categories', () => {
    expect(
      isRestaurantVenue([
        { id: '13065', name: 'Italian Restaurant' },
      ]),
    ).toBe(true);
    expect(isRestaurantCuisineLabel('Italian Restaurant, Pizza Place')).toBe(true);
  });

  it('accepts cafes and bars', () => {
    expect(isRestaurantVenue([{ id: '13032', name: 'Coffee Shop' }])).toBe(true);
    expect(isRestaurantVenue([{ id: '13389', name: 'Irish Pub' }])).toBe(true);
  });

  it('rejects hotels and retail', () => {
    expect(isRestaurantVenue([{ id: '19014', name: 'Hotel' }])).toBe(false);
    expect(isRestaurantVenue([{ id: '17000', name: 'Grocery Store' }])).toBe(false);
    expect(isRestaurantCuisineLabel('Hotel')).toBe(false);
    expect(isRestaurantCuisineLabel('Shopping Mall')).toBe(false);
  });

  it('rejects empty or missing categories', () => {
    expect(isRestaurantVenue([])).toBe(false);
    expect(isRestaurantCuisineLabel(null)).toBe(false);
    expect(isRestaurantCuisineLabel('')).toBe(false);
  });
});
