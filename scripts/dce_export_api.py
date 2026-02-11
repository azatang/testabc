"""
大连商品交易所 - 直接通过 API 下载结算参数数据
无需浏览器，速度最快
"""

import os
import requests
from datetime import datetime, timedelta

# ============== 配置 ==============
DOWNLOAD_DIR = r"U:\project\gitlab\python\testabc\downloads"

# 大商所 API（需要抓包确认实际地址）
# 以下为示例，实际地址需要通过浏览器开发者工具(F12) -> Network 抓取
BASE_URL = "http://www.dce.com.cn"
TARGET_URL = "http://www.dce.com.cn/dce/channel/list/181.html"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Referer": "http://www.dce.com.cn/dce/channel/list/181.html",
}


def get_settlement_params(trade_date: str = None):
    """
    获取结算参数数据
    
    Args:
        trade_date: 交易日期，格式 YYYYMMDD，默认今天
    
    Returns:
        响应数据
    """
    
    if trade_date is None:
        trade_date = datetime.now().strftime("%Y%m%d")
    
    # API 端点（需要根据实际抓包结果修改）
    # 通常交易所会有类似的数据接口
    api_endpoints = [
        # 结算参数 JSON 接口
        f"/publicweb/quotesdata/settleParams.html?tradeDate={trade_date}",
        f"/dalianshangpin/yw/fw/ywcs/jscs/settleParams_{trade_date}.json",
        f"/api/settleParams?date={trade_date}",
    ]
    
    session = requests.Session()
    session.headers.update(HEADERS)
    
    for endpoint in api_endpoints:
        url = BASE_URL + endpoint
        try:
            print(f"[INFO] 尝试: {url}")
            resp = session.get(url, timeout=10)
            if resp.status_code == 200:
                print(f"[SUCCESS] 获取数据成功")
                return resp
        except Exception as e:
            print(f"[WARN] {e}")
            continue
    
    return None


def download_excel_directly(trade_date: str = None):
    """
    直接下载 Excel 文件
    
    很多交易所网站的"导出表格"按钮实际上是一个直接下载链接
    """
    
    if trade_date is None:
        trade_date = datetime.now().strftime("%Y%m%d")
    
    os.makedirs(DOWNLOAD_DIR, exist_ok=True)
    
    # 可能的 Excel 下载链接（需要根据实际抓包结果修改）
    download_urls = [
        f"{BASE_URL}/publicweb/quotesdata/exportSettleParams.html?tradeDate={trade_date}&exportType=excel",
        f"{BASE_URL}/dalianshangpin/yw/fw/ywcs/jscs/export.html?date={trade_date}",
        f"{BASE_URL}/api/export/settleParams?date={trade_date}&format=xlsx",
    ]
    
    session = requests.Session()
    session.headers.update(HEADERS)
    
    for url in download_urls:
        try:
            print(f"[INFO] 尝试下载: {url}")
            resp = session.get(url, timeout=30, stream=True)
            
            if resp.status_code == 200:
                # 检查是否是文件
                content_type = resp.headers.get("Content-Type", "")
                if "excel" in content_type or "spreadsheet" in content_type or "octet-stream" in content_type:
                    # 获取文件名
                    cd = resp.headers.get("Content-Disposition", "")
                    if "filename=" in cd:
                        filename = cd.split("filename=")[-1].strip('"')
                    else:
                        filename = f"dce_settlement_{trade_date}.xls"
                    
                    filepath = os.path.join(DOWNLOAD_DIR, filename)
                    with open(filepath, "wb") as f:
                        for chunk in resp.iter_content(chunk_size=8192):
                            f.write(chunk)
                    
                    print(f"[SUCCESS] 文件已保存: {filepath}")
                    return filepath
                    
        except Exception as e:
            print(f"[WARN] {e}")
            continue
    
    print("[ERROR] 未能直接下载，请使用 Selenium/Playwright 方案")
    return None


def capture_download_url():
    """
    辅助函数：如何抓取下载链接
    
    步骤：
    1. 打开浏览器，按 F12 打开开发者工具
    2. 切换到 Network 标签页
    3. 点击网页上的"导出表格"按钮
    4. 在 Network 中找到下载请求
    5. 右键 -> Copy -> Copy as cURL
    6. 将 URL 和参数填入上面的 download_urls
    """
    print("""
    ==================== 如何抓取下载 URL ====================
    
    1. 打开浏览器访问大商所结算参数页面
    2. 按 F12 打开开发者工具
    3. 切换到 Network (网络) 标签页
    4. 勾选 "Preserve log" (保留日志)
    5. 点击页面上的 "导出表格" 按钮
    6. 在 Network 列表中找到下载请求（通常是 .xls 或包含 export 的请求）
    7. 右键该请求 -> Copy -> Copy URL
    8. 将 URL 填入本脚本的 download_urls 列表中
    
    =========================================================
    """)


if __name__ == "__main__":
    # 显示抓包说明
    capture_download_url()
    
    # 尝试直接下载
    result = download_excel_directly()
    
    if not result:
        print("\n如果直接下载失败，请使用以下命令运行 Selenium 版本：")
        print("  python scripts/dce_export.py")
