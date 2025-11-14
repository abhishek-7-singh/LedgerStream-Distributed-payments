import asyncio

from common.db import async_session_factory, init_engine


async def seed() -> None:
    init_engine()
    async with async_session_factory() as session:
        async with session.begin():
            pass  # Add seed data here when ready.


if __name__ == "__main__":
    asyncio.run(seed())
