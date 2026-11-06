package com.orionbeastfx.alerts;
import org.junit.Test;
import org.json.*;
import static org.junit.Assert.*;
public class EventReducerTest {
    @Test public void startsEmpty() throws Exception { assertFalse(new JSONObject().has("symbols")); }
    @Test public void watchToStandby() throws Exception {
        JSONObject s=EventReducer.apply(new JSONObject(),new JSONObject("{\"type\":\"symbol\",\"symbol\":\"TEST\",\"state\":\"watch\"}"),100);
        assertEquals("watch",s.getJSONObject("symbols").getJSONObject("TEST").getString("state"));
        s=EventReducer.apply(s,new JSONObject("{\"type\":\"symbol\",\"symbol\":\"TEST\",\"state\":\"standby\"}"),101);
        assertEquals("standby",s.getJSONObject("symbols").getJSONObject("TEST").getString("state"));
    }
    @Test public void snapshotReplacesList() throws Exception {
        JSONObject s=EventReducer.apply(new JSONObject(),new JSONObject("{\"type\":\"snapshot\",\"symbols\":[{\"symbol\":\"TEST\",\"state\":\"watch\"}]}"),100);
        s=EventReducer.apply(s,new JSONObject("{\"type\":\"snapshot\",\"symbols\":[]}"),101);
        assertEquals(0,s.getJSONObject("symbols").length());
    }
    @Test public void olderMessageDoesNotOverwrite() throws Exception {
        JSONObject s=EventReducer.apply(new JSONObject(),new JSONObject("{\"type\":\"symbol\",\"symbol\":\"TEST\",\"state\":\"standby\"}"),200);
        s=EventReducer.apply(s,new JSONObject("{\"type\":\"symbol\",\"symbol\":\"TEST\",\"state\":\"watch\"}"),100);
        assertEquals("standby",s.getJSONObject("symbols").getJSONObject("TEST").getString("state"));
    }
    @Test(expected=JSONException.class) public void invalidStateRejected() throws Exception {
        EventReducer.apply(new JSONObject(),new JSONObject("{\"type\":\"symbol\",\"symbol\":\"TEST\",\"state\":\"guess\"}"),1);
    }
    @Test public void summaryMissingMetricsStayMissing() throws Exception {
        JSONObject s=EventReducer.apply(new JSONObject(),new JSONObject("{\"type\":\"summary\",\"date\":\"2026-11-06\",\"trades\":0}"),1);
        JSONObject day=s.getJSONObject("summaries").getJSONObject("2026-11-06");assertEquals(0,day.getInt("trades"));assertFalse(day.has("net_r"));assertFalse(day.has("win_rate"));
    }
    @Test(expected=JSONException.class) public void impossibleRateRejected() throws Exception {
        EventReducer.apply(new JSONObject(),new JSONObject("{\"type\":\"summary\",\"date\":\"2026-11-06\",\"win_rate\":101}"),1);
    }
}
