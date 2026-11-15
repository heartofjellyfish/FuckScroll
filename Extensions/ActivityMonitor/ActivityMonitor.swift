import DeviceActivity

final class ActivityMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        #if DEBUG
        if activity.rawValue.hasPrefix(UsageProbe.prefix) { UsageProbe.record("interval-start", activity: activity.rawValue) }
        #endif
    }
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        #if DEBUG
        if UsageProbe.event(event, activity: activity) { return }
        #endif
        Monitoring.reachedThreshold(event: event, activity: activity)
    }
    override func intervalDidEnd(for activity: DeviceActivityName) {
        if ReminderTrial.intervalEnded(activity) { return }
        #if DEBUG
        if activity.rawValue.hasPrefix(UsageProbe.prefix) {
            UsageProbe.record("interval-end", activity: activity.rawValue)
            return
        }
        #endif
        Monitoring.sessionIntervalEnded(activity: activity)
        Monitoring.finishRest(activity: activity)
    }
}
