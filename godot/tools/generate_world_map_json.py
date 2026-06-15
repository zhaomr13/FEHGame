import json
import random
import math
import os

# Deterministic output
random.seed(42)

MAP_SIZE = {"x": 3840, "y": 2160}
MIN_DISTANCE = 70
MAX_AUTO_DISTANCE = 320
TARGET_CONNECTIONS = 3

# Region definitions: (count, x_range, y_range, first_faction, name_pool)
REGIONS = [
    (10,  (100,  3740), (100,  500),  "embla",  [
        "北境要塞", "冰风哨站", "霜狼营地", "雪原镇", "极光村",
        "冻土驿站", "寒铁堡", "白鸦哨所", "冬息村", "北望塔",
    ]),
    (22,  (500,  3340), (500,  1200), "askr",   [
        "王都阿斯卡", "中央广场", "圣骑士团驻地", "贤者之塔", "商业街",
        "南门集市", "东门工坊", "西门酒馆", "北门军营", "皇家图书馆",
        "治愈教会", "勇者大道", "冒险者公会", "旧城区", "新城区",
        "中央车站", "王立学院", "骑士训练场", "市民广场", "中央公园",
        "大钟楼", "市政厅",
    ]),
    (12,  (100,  1200), (600,  1500), "muspell", [
        "熔岩要塞", "炎狼巢穴", "灰烬哨站", "焦土村", "火晶矿场",
        "赤焰营地", "熔铁工坊", "热风驿站", "焰纹祭坛", "岩浆渡口",
        "焚风哨所", "炎狱之门",
    ]),
    (15,  (2640, 3740), (600,  1500), "nifl",   [
        "冰晶神殿", "雪精灵村", "极光观测站", "冰瀑镇", "霜语林地",
        "冰镜湖", "冬青驿站", "冰牙要塞", "雪豹营地", "寒冰矿坑",
        "冰风峡谷", "永冻港", "霜花村", "冰柱洞窟", "雪鸮哨站",
    ]),
    (12,  (500,  3340), (1500, 2060), None,     [
        "南风港", "绿洲镇", "沙漠驿站", "沙丘营地", "烈日要塞",
        "仙人掌村", "流沙渡口", "热风沙漠", "绿洲集市", "沙蝎巢穴",
        "落日哨站", "南方遗迹",
    ]),
    (9,   (100,  3740), (100,  2060), None,     [
        "边境哨站", "中立贸易站", "缓冲营地", "界碑村", "和平驿站",
        "三不管地带", "边境集市", "无人区前哨", "缓冲要塞",
    ]),
]

NODE_TYPES = ["city", "fort", "village"]
NODE_WEIGHTS = [0.6, 0.2, 0.2]

def generate_nodes():
    nodes = []
    node_id = 1
    for count, (x_min, x_max), (y_min, y_max), faction, name_pool in REGIONS:
        for i in range(count):
            attempts = 0
            while attempts < 1000:
                x = random.randint(x_min, x_max)
                y = random.randint(y_min, y_max)
                # Check minimum distance
                too_close = False
                for n in nodes:
                    dx = n["pos"]["x"] - x
                    dy = n["pos"]["y"] - y
                    if math.hypot(dx, dy) < MIN_DISTANCE:
                        too_close = True
                        break
                if not too_close:
                    break
                attempts += 1

            if attempts >= 1000:
                # Fallback: nudge from last successful position
                x = random.randint(x_min, x_max)
                y = random.randint(y_min, y_max)

            name = name_pool[i] if i < len(name_pool) else f"region{node_id}"
            ntype = random.choices(NODE_TYPES, weights=NODE_WEIGHTS)[0]
            nodes.append({
                "id": f"city_{node_id:02d}",
                "name": name,
                "type": ntype,
                "pos": {"x": x, "y": y},
                "faction": faction,
                "force_connections": [],
                "blocked_neighbors": [],
            })
            node_id += 1
    return nodes

def add_manual_connections(nodes):
    manual = [
        {"from": "city_10", "to": "city_11"},
        {"from": "city_22", "to": "city_33"},
        {"from": "city_32", "to": "city_45"},
        {"from": "city_28", "to": "city_60"},
        {"from": "city_44", "to": "city_72"},
        {"from": "city_59", "to": "city_80"},
    ]
    # Validate that all referenced nodes exist
    ids = {n["id"] for n in nodes}
    for conn in manual:
        assert conn["from"] in ids, f"Missing node {conn['from']}"
        assert conn["to"] in ids, f"Missing node {conn['to']}"
    return manual

def build_output():
    nodes = generate_nodes()
    manual = add_manual_connections(nodes)
    data = {
        "metadata": {
            "map_size": MAP_SIZE,
            "connection_strategy": "auto_with_overrides",
            "max_auto_distance": MAX_AUTO_DISTANCE,
            "target_connections": TARGET_CONNECTIONS,
        },
        "nodes": nodes,
        "manual_connections": manual,
    }
    return data

def main():
    data = build_output()
    out_path = os.path.join("godot", "data", "world_map.json")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Wrote {len(data['nodes'])} nodes to {out_path}")

if __name__ == "__main__":
    main()
