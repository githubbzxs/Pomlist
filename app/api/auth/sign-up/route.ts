import { errorResponse } from "@/lib/http";

export async function POST() {
  return errorResponse("SIGN_UP_DISABLED", "注册入口已关闭，请使用口令登录。", 410);
}
