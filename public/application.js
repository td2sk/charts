console.log("ok");
window.onload = function (){
    var dataset = {};
    var ws = new WebSocket('ws://' + window.location.host + window.location.pathname);

    var chart = c3.generate({
        bindto: '#chart',
        data: {
            columns: []
        }
    });

    var add = function(table, key, value) {
        table[key] = table[key] || [key];
        table[key].push(value);
    };

    var values = function(hash) {
        var ret = [];
        for (var key in hash) {
           ret.push(hash[key]);
        } 
        return ret;
    };

    ws.onopen = function() { 
        console.log("connection opened");
    }
    ws.onclose = function() { 
        console.log("connection closed");
    }

    var labels = {};
    var columns = {};

    ws.onmessage = function(m) {
        console.log("on message");
        var data = JSON.parse(m.data);

        for (var i = 0; i < data.length; ++i) {
            var datum = data[i];
            var key = datum.key
            var x = datum.x;
            var y = datum.y;

            labels[datum.key] = '_' + datum.key;
            add(columns, '_' + datum.key, datum.x);
            add(columns, datum.key, datum.y);
        }

        chart.load({
            xs: labels,
            columns: values(columns)
        });
    }
};
