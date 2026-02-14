import { describe, expect, it } from "vitest";

import {
  isUuid,
  isValidPasscode,
  mergeTodoTagsWithCategory,
  normalizeDueAt,
  normalizePriority,
  normalizeText,
  normalizeTitle,
  normalizeTodoCategory,
  normalizeTodoTags,
  uniqueIds,
} from "../lib/validation";

describe("validation", () => {
  it("标题规范化", () => {
    expect(normalizeTitle("  任务A  ")).toBe("任务A");
    expect(normalizeTitle("")).toBeNull();
    expect(normalizeTitle(null)).toBeNull();
  });

  it("文本规范化", () => {
    expect(normalizeText("  备注  ", 10)).toBe("备注");
    expect(normalizeText("", 10)).toBeNull();
    expect(normalizeText(undefined, 10)).toBeNull();
  });

  it("优先级规范化", () => {
    expect(normalizePriority(1)).toBe(1);
    expect(normalizePriority(2)).toBe(2);
    expect(normalizePriority(3)).toBe(3);
    expect(normalizePriority(99)).toBe(3);
    expect(normalizePriority("abc")).toBeNull();
  });

  it("日期规范化", () => {
    expect(normalizeDueAt("2026-02-13T08:00")).toBeTypeOf("string");
    expect(normalizeDueAt("invalid")).toBeNull();
  });

  it("UUID 与去重", () => {
    const valid = "550e8400-e29b-41d4-a716-446655440000";
    expect(isUuid(valid)).toBe(true);
    expect(isUuid("bad-id")).toBe(false);
    expect(uniqueIds(["a", "a", "b"])).toEqual(["a", "b"]);
  });

  it("口令长度校验", () => {
    expect(isValidPasscode("0xbp")).toBe(true);
    expect(isValidPasscode("123")).toBe(false);
    expect(isValidPasscode("12345")).toBe(false);
  });

  it("分类与标签规范化", () => {
    expect(normalizeTodoCategory(undefined)).toBe("未分类");
    expect(normalizeTodoCategory("学习")).toBe("学习");
    expect(normalizeTodoCategory(123)).toBeNull();

    expect(normalizeTodoTags(["深度工作", "复盘", "复盘"])).toEqual(["深度工作", "复盘"]);
    expect(normalizeTodoTags(["深度工作", "复盘", "计划"])).toBeNull();
    expect(normalizeTodoTags(undefined)).toEqual([]);
    expect(normalizeTodoTags(["a".repeat(21)])).toBeNull();
    expect(mergeTodoTagsWithCategory([], "学习")).toEqual(["学习"]);
  });
});

