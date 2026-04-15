from fastmcp import FastMCP
import subprocess

# إنشاء سيرفر MCP باسم Muzhir
mcp = FastMCP("Muzhir-Backend")

@mcp.tool()
async def check_project_status():
    return "Muzhir Backend is connected via MCP and ready to build!"

@mcp.tool()
async def run_fastapi_test():
    return "FastAPI endpoints are reachable (Mock Test)."

if __name__ == "__main__":
    mcp.run()
