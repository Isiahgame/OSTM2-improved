package ostm.item;

class WeaponType extends ItemType {
    public var attackSpeed(default, null) :Float;

    public function new(data) {
        super({
            id: data.id,
            names: data.names,
            slot: Weapon,
            attack: data.attack,
            defense: data.defense,
        });

        attackSpeed = data.attackSpeed;
    }
}