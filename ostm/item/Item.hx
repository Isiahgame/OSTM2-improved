package ostm.item;

import js.*;
import js.html.*;

import jengine.Vec2;
import jengine.util.*;

import ostm.KeyboardManager;
import ostm.battle.BattleManager;
import ostm.battle.StatModifier;
import ostm.item.Affix;
import ostm.item.ItemType;
import ostm.map.MapGenerator;

class Item {
    public var type(default, null) :ItemType;
    var itemLevel :Int; // Level this item spawned at
    var level :Int; // Level this item rolled
    var isOwned :Bool;

    var tier(get, null) :Int;

    var affixes :Array<Affix> = [];

    var _elem :Element;
    var _body :Element;
    var _buttons :Element;
    var _cachedPowerDelta :Int;

    static inline var kTierLevels :Int = 5;

    public function new(type :ItemType, level :Int) {
        this.type = type;
        this.itemLevel = level;
        this.level = level;
    }

    public function setDropLevel(level :Int) :Void {
        this.level = level;
    }

    public function rollAffixes(nAffixes :Int) :Void {
        var possibleAffixes = AffixData.affixTypes.filter(function (affixType) { return affixType.canGoInSlot(type.slot); });
        var selectedAffixes = Random.randomElements(possibleAffixes, nAffixes);
        for (type in selectedAffixes) {
            var affix = new Affix(type, this.type.slot);
            affix.rollItemLevel(this.itemLevel);
            affixes.push(affix);
            nAffixes--;
        }
    }

    public function name() :String {
        var t = Math.floor(tier / type.names.length) + 1;
        var name = type.names[tier % type.names.length];
        if (t > 1 && type.names.length > 1) {
            name = 'T' + t + ' ' + name;
        }
        return name;
    }

    public function image() :String {
        var image = type.images[tier % type.images.length];
        return 'img/items/' + image;
    }

    public function equip() {
        var player = BattleManager.instance.getPlayer();
        var cur = player.equipment[type.slot];
        if (cur != null) {
            Inventory.instance.swap(this, cur);
        }
        else {
            Inventory.instance.remove(this);
        }
        player.equip(this);

        cleanupElement();
    }

    public function discard() {
        if (MapGenerator.instance.isInTown()) {
            BattleManager.instance.getPlayer().addGold(sellValue());
        }
        
        Inventory.instance.remove(this);

        cleanupElement();
    }

    public function unequip() {
        var player = BattleManager.instance.getPlayer();
        var cur = player.equipment[type.slot];
        if (cur == this && Inventory.instance.hasSpaceForItem()) {
            cleanupElement();

            player.unequip(this);
            Inventory.instance.push(this);
        }
    }

    function getColor() :String {
        if (affixes.length > 4) {
            return '#ff2222';
        }
        if (affixes.length > 2) {
            return '#ffff22';
        }
        if (affixes.length > 0) {
            return '#2277ff';
        }
        return '#ffffff';
    }

    function hideBothBodies() {
        hideBody();

        var player = BattleManager.instance.getPlayer();
        var equipped = player.equipment.get(type.slot);
        if (equipped != null && equipped != this) {
            equipped.hideBody();
        }
    }

    public function createElement(buttons :Map<String, Event -> Void>) :Element {
        var player = BattleManager.instance.getPlayer();

        var makeNameElem = function() {
            var name = Browser.document.createSpanElement();
            name.innerText = this.name();
            name.style.color = getColor();
            return name;
        }
        var _elem = Browser.document.createSpanElement();
        _elem.className = 'item';
        _elem.style.background = getColor();

        var img = Browser.document.createImageElement();
        img.src = image();
        _elem.appendChild(img);

        _buttons = Browser.document.createSpanElement();
        _buttons.className = 'item-buttons';

        var index = 0;
        var clickFuncs :Array<MouseEvent -> Void> = [];
        for (k in buttons.keys()) {
            var f = buttons[k];
            var btn = Browser.document.createButtonElement();
            btn.onclick = f;
            btn.innerText = k;
            _buttons.appendChild(btn);

            // This gets triggered when we sell-click too quickly; disable for now
            // if (index == 0) {
            //     img.ondblclick = f;
            // }
            clickFuncs.push(f);
            index++;
        }
        if (clickFuncs.length > 0) {
            img.onclick = function(event) {
                var checks = [
                    KeyboardManager.instance.isShiftHeld,
                    KeyboardManager.instance.isCtrlHeld,
                ];

                for (i in 0...checks.length) {
                    if (clickFuncs.length > i && checks[i]) {
                        clickFuncs[i](event);
                    }
                }
            };
        }

        _body = Browser.document.createUListElement();
        _body.className = 'tooltip';
        _body.appendChild(makeNameElem());
        hideBody();
        _buttons.style.display = 'none';

        _elem.onmouseover = function(event :MouseEvent) {
            _buttons.style.display = '';
            var pos = new Vec2(event.x - 275, event.y - 30);
            showBody(pos);

            var equipped = player.equipment.get(type.slot);
            if (equipped != null && equipped != this) {
                equipped.showBody(pos + new Vec2(_body.clientWidth + 75, 0));
            }
        };
        _elem.onmouseout = function(event) {
            _buttons.style.display = 'none';
            hideBothBodies();
        };

        _body.style.position = 'absolute';
        _body.style.background = '#444444';
        _body.style.border = '2px solid #000000';
        _body.style.width = cast 190;
        _body.style.zIndex = cast 10;

        var dlvl = Browser.document.createLIElement();
        dlvl.innerText = 'Drop Lvl: ' + Util.format(dropLevel());
        _body.appendChild(dlvl);

        var ilvl = Browser.document.createLIElement();
        ilvl.innerText = 'iLvl: ' + Util.format(itemLevel);
        _body.appendChild(ilvl);

        var atk = Browser.document.createLIElement();
        atk.innerText = 'Attack: ' + Util.format(attack());
        _body.appendChild(atk);

        if (Std.is(type, WeaponType)) {
            var spd = Browser.document.createLIElement();
            spd.innerText = 'Speed: ' + Util.formatFloat(attackSpeed()) + '/s';
            _body.appendChild(spd);

            var crt = js.Browser.document.createLIElement();
            crt.innerText = 'Crit Rating: ' + Util.format(critRating());
            _body.appendChild(crt);
        }
        var def = Browser.document.createLIElement();
        def.innerText = 'Defense: ' + Util.format(defense());
        _body.appendChild(def);

        for (affix in affixes) {
            var aff = Browser.document.createLIElement();
            aff.innerText = affix.text();
            aff.className = 'item-affix';
            _body.appendChild(aff);
        }

        var powElem = Browser.document.createLIElement();
        var oldPow = player.power();
        var newPow = player.powerIfEquipped(this);
        _cachedPowerDelta = newPow - oldPow;
        var powStr = 'Power: ';
        if (_cachedPowerDelta > 0) {
            powElem.className = 'item-power-increase';
            powStr += '+';
        }
        else if (_cachedPowerDelta < 0) {
            powElem.className = 'item-power-decrease';
        }
        powStr += Util.format(_cachedPowerDelta);
        powElem.innerText = powStr;
        _body.appendChild(powElem);

        var buy = Browser.document.createLIElement();
        buy.innerText = 'Buy Price: ' + Util.shortFormat(buyValue());
        _body.appendChild(buy);
        var sell = Browser.document.createLIElement();
        sell.innerText = 'Sell Price: ' + Util.shortFormat(sellValue());
        _body.appendChild(sell);

        if (_cachedPowerDelta > 0) {
            var eqHint = Browser.document.createDivElement();
            eqHint.className = 'item-equip-hint';
            _elem.appendChild(eqHint);
        }
        _elem.appendChild(_buttons);

        Browser.document.getElementById('popup-container').appendChild(_body);

        return _elem;
    }

    public function cleanupElement() :Void {
        hideBothBodies();
        
        if (_body != null) {
            _body.remove();
        }
    }

    function showBody(atPos :Vec2) :Void {
        if (_body == null) {
            return;
        }

        _body.style.display = '';
        _body.style.left = cast atPos.x;
        _body.style.top = cast atPos.y;
    }
    function hideBody() :Void {
        if (_body == null) {
            return;
        }
        
        _body.style.display = 'none';
    }

    public function sumAffixes(?mod :StatModifier) :StatModifier {
        if (mod == null) {
            mod = new StatModifier();
        }
        for (affix in affixes) {
            affix.applyModifier(mod);
        }
        return mod;
    }
    public function subtractAffixes(mod :StatModifier) :StatModifier {
        for (affix in affixes) {
            affix.subtractModifier(mod);
        }
        return mod;
    }

    public function attack() :Int {
        var mod = sumAffixes();
        var atk = type.attack;
        atk *= 1 + kTierLevels * 0.4 * tier;
        atk += mod.localFlatAttack;
        atk *= 1 + mod.localPercentAttack / 100;
        return Math.round(atk);
    }
    public function attackSpeed() :Float {
        if (!Std.is(type, WeaponType)) {
            return 0;
        }
        var wep :WeaponType = cast(type, WeaponType);
        var mod = sumAffixes();
        var spd = wep.attackSpeed;
        spd *= 1 + mod.localPercentAttackSpeed / 100;        
        return spd;
    }
    public function critRating() :Int {
        var crt :Float = 0;
        if (Std.is(type, WeaponType)) {
            var wep :WeaponType = cast(type, WeaponType);
            crt = wep.crit;
            crt *= 1 + kTierLevels * 0.1 * tier;
        }
        var mod = sumAffixes();
        crt += mod.localFlatCritRating;
        crt *= 1 + mod.localPercentCritRating / 100;        
        return Math.round(crt);
    }
    public function defense() :Int {
        var mod = sumAffixes();
        var def = type.defense;
        def *= 1 + kTierLevels * 0.4 * tier;
        def += mod.localFlatDefense;
        def *= 1 + mod.localPercentDefense / 100;
        return Math.round(def);
    }

    public function buyValue() :Int {
        var value = Math.pow(tier + 1, 2.2) * 10;
        var mult = 1.0;
        for (affix in affixes) {
            mult += affix.value();
        }
        return Math.round(value * mult);
    }
    public function sellValue() :Int {
        return Math.round(Math.pow(buyValue(), 0.85) * 0.5);
    }

    public function numAffixes() :Int {
        return affixes.length;
    }

    public function powerDelta() :Int {
        return _cachedPowerDelta;
    }

    function get_tier() :Int {
        return Math.floor(this.level / kTierLevels);
    }

    function dropLevel() :Int {
        var dropLevel = tier * kTierLevels;
        return dropLevel > 0 ? dropLevel : 1;
    }

    public function serialize() :Dynamic {
        return {
            id: type.id,
            itemLevel: itemLevel,
            level: level,
            isOwned: isOwned,
            affixes: affixes.map(function (affix) { return affix.serialize(); }),
        };
    }
    public static function loadItem(data :Dynamic) :Item {
        for (type in ItemData.types) {
            if (data.id == type.id) {
                var item = new Item(type, 0);
                item.level = data.level;
                item.isOwned = data.isOwned;
                item.itemLevel = data.itemLevel;
                item.tier = Math.floor(item.level / kTierLevels);
                item.affixes = data.affixes.map(function (d) { return Affix.loadAffix(d); });
                return item;
            }
        }
        return null;
    }
}
