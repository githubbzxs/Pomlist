const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SIMPLE_EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PASSCODE_LENGTH = 4;

export const DEFAULT_TODO_CATEGORY = "未分类";
export const TODO_CATEGORY_MAX_LENGTH = 32;
export const TODO_TAG_MAX_COUNT = 10;
export const TODO_TAG_MAX_LENGTH = 20;

export function isUuid(value: string): boolean {
  return UUID_REGEX.test(value);
}

export function isValidEmail(value: string): boolean {
  return SIMPLE_EMAIL_REGEX.test(value);
}

export function isValidPasscode(value: string): boolean {
  return value.length === PASSCODE_LENGTH;
}

export function normalizeTitle(input: unknown): string | null {
  if (typeof input !== "string") {
    return null;
  }
  const trimmed = input.trim();
  if (trimmed.length < 1 || trimmed.length > 200) {
    return null;
  }
  return trimmed;
}

export function normalizeText(input: unknown, maxLength: number): string | null {
  if (input === undefined || input === null) {
    return null;
  }
  if (typeof input !== "string") {
    return null;
  }
  const trimmed = input.trim();
  if (trimmed.length === 0) {
    return null;
  }
  return trimmed.slice(0, maxLength);
}

export function normalizePriority(input: unknown): 1 | 2 | 3 | null {
  if (input === undefined || input === null) {
    return null;
  }
  const parsed = typeof input === "number" ? input : Number(input);
  if (!Number.isFinite(parsed)) {
    return null;
  }
  if (parsed <= 1) {
    return 1;
  }
  if (parsed >= 3) {
    return 3;
  }
  return 2;
}

export function normalizeDueAt(input: unknown): string | null {
  if (input === undefined || input === null || input === "") {
    return null;
  }
  if (typeof input !== "string") {
    return null;
  }
  const date = new Date(input);
  if (Number.isNaN(date.getTime())) {
    return null;
  }
  return date.toISOString();
}

export function uniqueIds(input: string[]): string[] {
  return Array.from(new Set(input.filter((item) => item.trim() !== "")));
}

export function normalizeTodoCategory(input: unknown): string | null {
  if (input === undefined || input === null || input === "") {
    return DEFAULT_TODO_CATEGORY;
  }
  if (typeof input !== "string") {
    return null;
  }

  const trimmed = input.trim();
  if (trimmed === "") {
    return DEFAULT_TODO_CATEGORY;
  }
  if (trimmed.length > TODO_CATEGORY_MAX_LENGTH) {
    return null;
  }

  return trimmed;
}

export function normalizeTodoTags(input: unknown): string[] | null {
  if (input === undefined || input === null) {
    return [];
  }
  if (!Array.isArray(input)) {
    return null;
  }

  const normalized: string[] = [];
  const seen = new Set<string>();

  for (const rawTag of input) {
    if (typeof rawTag !== "string") {
      return null;
    }

    const tag = rawTag.trim();
    if (tag === "") {
      continue;
    }
    if (tag.length > TODO_TAG_MAX_LENGTH) {
      return null;
    }
    if (seen.has(tag)) {
      continue;
    }
    seen.add(tag);
    normalized.push(tag);
  }

  if (normalized.length > TODO_TAG_MAX_COUNT) {
    return null;
  }

  return normalized;
}

