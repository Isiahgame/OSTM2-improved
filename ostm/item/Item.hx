package ostm.item;

import js.*;
import js.html.*;

import jengine.Vec2;
import jengine.util.*;

import ostm.battle.BattleManager;
import ostm.item.Affix;
import ostm.item.ItemType;

class Item {
    public var type(default, null) :ItemType;
    var itemLevel :Int; // Level this item spawned at
    var level :Int; // Level this item rolled

    var affixes :Array<Affix> = [];

    var _elem :Element;
    var _body :Element;
    var _buttons :Element;

    public function new(type :ItemType, level :Int) {
        this.type = type;
        this.itemLevel = level;
        this.level = Random.randomIntRange(1, level + 1);

        var nAffixes = Random.randomIntRange(0, 4);
        var possibleAffixes = Affix.affixTypes.filter(function (affixType) { return affixType.canGoInSlot(type.slot); });
        var selectedAffixes = Random.randomElements(possibleAffixes, nAffixes);
        for (type in selectedAffixes) {
            var affix = new Affix(type, this.type.slot);
            affix.rollItemLevel(this.itemLevel);
            affixes.push(affix);
            nAffixes--;
        }
    }

    public function name() :String {
        return 'L' + level + ' ' + type.name;
    }

    function equip(event) {
        var player = BattleManager.instance.getPlayer();
        var cur = player.equipment[type.slot];
        if (cur != null) {
            Inventory.instance.push(cur);
        }
        player.equip(this);
        Inventory.instance.remove(this);

        cleanupElement();
        Inventory.instance.updateInventoryHtml();
    }

    function discard(event) {
        Inventory.instance.remove(this);

        cleanupElement();
        Inventory.instance.updateInventoryHtml();
    }

    function unequip(event) {
        var player = BattleManager.instance.getPlayer();
        var cur = player.equipment[type.slot];
        if (cur == this && Inventory.instance.hasSpaceForItem()) {
            player.unequip(this);

            Inventory.instance.push(this);
            Inventory.instance.updateInventoryHtml();
        }
    }

    function getColor() :String {
        switch (affixes.length) {
            case 3: return '#ffff00';
            case 2: return '#0099ff';
            case 1: return '#22ff22';
            default: return '#ffffff';
        }
    }

    public function createElement(elemTag :String) :Element {
        var player = BattleManager.instance.getPlayer();
        var equipped = player.equipment.get(type.slot);
        var isEquipped = this == equipped;

        _elem = Browser.document.createElement(elemTag);

        var makeNameElem = function() {
            var name = Browser.document.createSpanElement();
            name.innerText = this.name();
            name.style.color = getColor();
            return name;
        }
        _elem.appendChild(makeNameElem());

        _buttons = Browser.document.createSpanElement();
        _elem.appendChild(_buttons);

        if (!isEquipped) {
            var equip = Browser.document.createButtonElement();
            equip.innerText = 'Equip';
            equip.onclick = this.equip;
            _buttons.appendChild(equip);

            var discard = Browser.document.createButtonElement();
            discard.innerText = 'Discard';
            discard.onclick = this.discard;
            _buttons.appendChild(discard);
        }
        else {
            var unequip = Browser.document.createButtonElement();
            unequip.innerText = 'Unequip';
            unequip.onclick = this.unequip;
            _buttons.appendChild(unequip);
        }

        _body = Browser.document.createUListElement();
        _body.appendChild(makeNameElem());
        hideBody();
        _buttons.style.display = 'none';

        _elem.onmouseover = function(event :MouseEvent) {
            _buttons.style.display = '';
            var pos = new Vec2(event.x, event.y);
            showBody(pos);

            if (equipped != null && !isEquipped) {
                equipped.showBody(pos + new Vec2(_body.clientWidth + 50, 0));
            }
        };
        _elem.onmouseout = function(event) {
            _buttons.style.display = 'none';
            hideBody();

            if (equipped != null && !isEquipped) {
                equipped.hideBody();
            }
        };

        _body.style.position = 'absolute';
        _body.style.background = '#444444';
        _body.style.border = '2px solid #000000';
        _body.style.width = cast 220;
        _body.style.zIndex = cast 10;

        var ilvl = Browser.document.createLIElement();
        ilvl.innerText = 'iLvl: ' + Util.format(itemLevel);
        _body.appendChild(ilvl);

        var atk = Browser.document.createLIElement();
        atk.innerText = 'Attack: ' + Util.format(attack());
        _body.appendChild(atk);

        if (Std.is(type, WeaponType)) {
            var spd = Browser.document.createLIElement();
            spd.innerText = 'Speed: ' + Util.formatFloat(attackSpeed());
            _body.appendChild(spd);
        }
        var def = Browser.document.createLIElement();
        def.innerText = 'Defense: ' + Util.format(defense());
        _body.appendChild(def);

        for (affix in affixes) {
            var aff = Browser.document.createLIElement();
            aff.innerText = affix.text();
            aff.style.fontStyle = 'italic';
            _body.appendChild(aff);
        }

        Browser.document.getElementById('popup-container').appendChild(_body);

        return _elem;
    }

    public function cleanupElement() :Void {
        if (_body != null) {
            _body.remove();
        }
    }

    function showBody(atPos :Vec2) :Void {
        _body.style.display = '';
        _body.style.left = cast atPos.x;
        _body.style.top = cast atPos.y;
    }
    function hideBody() :Void {
        _body.style.display = 'none';
    }

    public function sumAffixes(?mod :AffixModifier) :AffixModifier {
        if (mod == null) {
            mod = new AffixModifier();
        }
        for (affix in affixes) {
            affix.applyModifier(mod);
        }
        return mod;
    }

    public function attack() :Int {
        var atk = Math.round(type.attack * (1 + 0.4 * (level - 1)));
        return atk + sumAffixes().flatAttack;
    }
    public function attackSpeed() :Float {
        if (!Std.is(type, WeaponType)) {
            return 0;
        }
        var wep :WeaponType = cast(type, WeaponType);
        var spd = wep.attackSpeed;
        var mod = sumAffixes();
        return wep.attackSpeed * (1 + mod.localPercentAttackSpeed / 100);
    }
    public function defense() :Int {
        var def = Math.round(type.defense * (1 + 0.4 * (level - 1)));
        return def + sumAffixes().flatDefense;
    }

    public function serialize() :Dynamic {
        return {
            id: type.id,
            itemLevel: itemLevel,
            level: level,
            affixes: affixes.map(function (affix) { return affix.serialize(); }),
        };
    }
    public static function loadItem(data :Dynamic) :Item {
        for (type in Inventory.itemTypes) {
            if (data.id == type.id) {
                var item = new Item(type, 0);
                item.level = data.level;
                item.itemLevel = data.itemLevel;
                item.affixes = data.affixes.map(function (d) { return Affix.loadAffix(d); });
                return item;
            }
        }
        return null;
    }
}
