package jengine;

import haxe.Timer;

class Time {
    public static var dt(default, null): Float;
    public static var elapsed(default, null): Float;
    public static var timeMultiplier :Float = 1;
    public static var raw(get, null) :Float;

    static var _lastTime: Float;
    static var _startTime: Float;

    public static function init() :Void {
        dt = 0;
        elapsed = 0;

        _startTime = Timer.stamp();
        _lastTime = _startTime;
    }

    public static function update() :Void {
        var curTime: Float = Timer.stamp();

        dt = (curTime - _lastTime) * timeMultiplier;
        elapsed = curTime - _startTime;

        _lastTime = curTime;
    }

    static function get_raw() :Float {
        return Timer.stamp();
    }
}
