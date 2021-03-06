package ostm;

import js.*;
import js.html.*;

import jengine.*;
import jengine.SaveManager;
import jengine.util.Random;
import jengine.util.Util;

import ostm.battle.BattleManager;
import ostm.battle.BattleMember;
import ostm.item.Inventory;
import ostm.item.Item;
import ostm.map.MapGenerator;
import ostm.map.MapNode;

typedef ShopData = {
    generateTime :Int,
    items :Array<Item>,
}
typedef ShopSaveData = {
    i :Int,
    j :Int,
    genTime :Int,
    items :Array<Dynamic>,
};

class TownManager extends Component
        implements Saveable {
    public var saveId(default, null) :String = 'town-manager';
    var _shops = new Map<MapNode, ShopData>();
    var _lastNode :MapNode = null;
    public var shouldWarp(default, null) :Bool = false;

    var _warpButton :Element;
    var _townScreen :Element;
    var _shopClock :Element;
    var _capacityPrice :Element;
    var _goldElem :Element;
    var _gemsElem :Element;

    var _player :BattleMember;

    static inline var kShopRefreshTime = 300;

    public static var instance(default, null) :TownManager;

    public override function init() :Void {
        instance = this;
    }

    public override function start() :Void {
        SaveManager.instance.addItem(this);

        _player = BattleManager.instance.getPlayer();

        _townScreen = Browser.document.getElementById('town-screen');
        _shopClock = Browser.document.getElementById('town-shop-clock');
        _capacityPrice = Browser.document.getElementById('town-shop-capacity-price');
        
        _goldElem = Browser.document.getElementById('town-shop-gold');
        _gemsElem = Browser.document.getElementById('town-shop-gems');

        _warpButton = Browser.document.getElementById('town-warp-button');
        _warpButton.onclick = function(event) {
            shouldWarp = !shouldWarp;
            updateWarpButton();
        };
        updateWarpButton();

        var rebirthButton = Browser.document.getElementById('town-rebirth-button');
        rebirthButton.onclick = function(event) {
            _player.doRebirth();
            updateRebirthInfo();
        };

        var restockButton = Browser.document.getElementById('town-shop-restock-button');
        restockButton.onclick = function(event) {
            var mapNode = MapGenerator.instance.selectedNode;
            var price = restockPrice(mapNode);
            if (price <= _player.gold) {
                _player.addGold(-price);
                generateItems(mapNode);
                updateShopHtml(mapNode);
                updateRestockPrice(mapNode);
            }
        };

        var capacityButton = Browser.document.getElementById('town-shop-capacity-button');
        capacityButton.onclick = function(event) {
            var price = Inventory.instance.capacityUpgradeCost();
            if (price <= _player.gems) {
                _player.addGems(-price);
                Inventory.instance.upgradeCapacity();
                updateCapacityPrice();
            }
        };
    }

    public override function update() :Void {
        var mapNode = MapGenerator.instance.selectedNode;
        var inTown = mapNode.isTown();

        if (!inTown) {
            shouldWarp = false;
            updateWarpButton();
        }
        else { // in town
            var shop = _shops[mapNode];
            if (shop == null) {
                shop = {
                    generateTime: 0,
                    items: [],
                };
                _shops[mapNode] = shop;
            }
            if (shop.generateTime + kShopRefreshTime <= Time.raw) {
                generateItems(mapNode);
            }

            var refreshTime = Math.round(shop.generateTime + kShopRefreshTime - Time.raw);
            _shopClock.innerText = Util.format(refreshTime);

            if (mapNode != _lastNode) {
                updateShopHtml(mapNode);
                updateCapacityPrice();
                updateRebirthInfo();
            }
            updateRestockPrice(mapNode);
            _goldElem.innerText = Util.format(_player.gold);
            _gemsElem.innerText = Util.format(_player.gems);
        }
        _townScreen.style.display = inTown ? '' : 'none';

        _lastNode = mapNode;
    }

    function generateItems(mapNode :MapNode) :Void {
        var items = [];

        var nItems = 6;
        while (items.length < nItems) {
            var item = Inventory.instance.randomItem(mapNode.areaLevel());
            if (item.numAffixes() > 0) {
                items.push(item);
            }
        }

        var shop = _shops[mapNode];
        if (shop.items != null) {
            for (item in shop.items) {
                item.cleanupElement();
            }
        }
        shop.items = items;
        shop.generateTime = Math.round(Time.raw);

        updateShopHtml(mapNode);
    }

    function updateShopHtml(mapNode :MapNode) :Void {
        var shopElem = Browser.document.getElementById('town-shop');
        while (shopElem.childElementCount > 0) {
            shopElem.removeChild(shopElem.firstChild);
        }

        var items = _shops[mapNode].items;
        for (item in items) {
            shopElem.appendChild(item.createElement([
                'Buy' => function(event) {
                    var price = item.buyValue();
                    if (Inventory.instance.hasSpaceForItem() &&
                        _player.gold >= price) {
                        _player.addGold(-price);
                        items.remove(item);
                        item.cleanupElement();
                        Inventory.instance.push(item);
                        updateShopHtml(mapNode);
                    }
                },
            ]));
        }
    }

    function updateWarpButton() :Void {
        _warpButton.innerText = shouldWarp ? 'Disable' : 'Enable';
    }

    function restockPrice(mapNode :MapNode) :Int {
        var items = _shops[mapNode].items;
        var price = 0;
        for (item in items) {
            price += item.buyValue() - item.sellValue();
        }
        return price;
    }

    function updateRestockPrice(mapNode :MapNode) :Void {
        var label = Browser.document.getElementById('town-shop-restock-price');
        label.innerText = Util.format(restockPrice(mapNode));
    }

    function updateCapacityPrice() :Void {
        _capacityPrice.innerText = Util.format(Inventory.instance.capacityUpgradeCost());
    }

    function updateRebirthInfo() :Void {
        var canRebirth = _player.level >= 50;
        var rebirthElem = Browser.document.getElementById('town-rebirth');
        rebirthElem.style.display = canRebirth ? '' : 'none';
        if (!canRebirth) {
            return;
        }

        var pointElem = Browser.document.getElementById('town-rebirth-points');
        pointElem.innerText = Util.format(_player.rebirthSkillPoints());

        var levelElem = Browser.document.getElementById('town-rebirth-levels');
        levelElem.innerText = Util.format(_player.storedLevels);
        
        var gainElem = Browser.document.getElementById('town-rebirth-points-gained');
        gainElem.innerText = Util.format(_player.pointsGainedOnRebirth());

        var nextElem = Browser.document.getElementById('town-rebirth-next');
        nextElem.innerText = Util.format(_player.levelsToNextRebirthPoint());
    }

    public function serialize() :Dynamic {
        var shops = new Array<ShopSaveData>();
        for (node in _shops.keys()) {
            var i = node.depth;
            var j = node.height;
            var shop = _shops[node];
            var items = shop.items.map(function (item) {
                return item.serialize();
            });
            shops.push({
                i: i,
                j: j,
                genTime: shop.generateTime,
                items: items,
            });
        }
        return {
            shops: shops,
        };
    }
    public function deserialize(data :Dynamic) :Void {
        var shops :Array<ShopSaveData> = data.shops;
        for (shopData in shops) {
            var i = shopData.i;
            var j = shopData.j;
            var node = MapGenerator.instance.getNode(i, j);
            var items = shopData.items.map(function (itemData) {
                return Item.loadItem(itemData);
            });
            _shops[node] = {
                generateTime: shopData.genTime,
                items: items,
            };
        }
    }
}
