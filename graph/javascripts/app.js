
$(document).ready( function () {

  // Set up a bit of place holder to keep track of things while we refresh.
  window.selected_metric_names = [];
  window.timestamps = [];
  window.curr_min_index = 0;
  window.curr_max_index = 999999999; // A really big number...

  function reloadStatNames() {
    $.ajax( {
      type: "GET",
      url: "/names",
      data: "",
      contentType: "application/json; charset=utf-8",
      dataType: "json",
      success: function ( data, status, xhr ) {
        $("#metric_names").empty();
        $.each( data, function( index, value ) {
          $("#metric_names").append( $("<option/>").attr( "value", value).text( value ) );
        } );
        $("#metric_names").val( window.selected_metric_names );

        handleResize();

        $( '#metric_names' ).filterByText( '#name_filter' );
        $( '#name_filter' ).val( '' );

      },
      error: function () {
        alert( "Error loading stat names." );
      }
    } );
  };

  function updateTimestampText() {

    if( window.timestamps.length > 0 ) {
      var min_date = new Date( window.timestamps[ window.curr_min_index ] * 1000 );
      var max_date = new Date( window.timestamps[ window.curr_max_index ] * 1000 );

      var min_string = min_date.toISOString();
      var max_string = max_date.toISOString();

      $("#min_timestamp").empty();
      $("#min_timestamp").append( min_string );
      $("#max_timestamp").empty();
      $("#max_timestamp").append( max_string );
    }
  }

  function reloadSlider() {
    $.ajax( {
      type: "GET",
      url: "/timestamps",
      data: "",
      contentType: "application/json; charset=utf-8",
      dataType: "json",
      success: function ( data, status, xhr ) {

        function handleChange( event, ui ) {

          window.curr_min_index = ui.values[0];
          window.curr_max_index = ui.values[1];

          updateTimestampText();
        }

        var prev_abs_min_index = window.abs_min_index || 0;
        var prev_abs_max_index = window.abs_max_index || 999999999;

        if( window.curr_max_index > prev_abs_max_index ) {
          window.curr_max_index = prev_abs_max_index;
        }

        window.timestamps = data;

        var new_abs_min_index = 0;
        var new_abs_max_index = data.length - 1;

        if( window.curr_min_index == prev_abs_min_index ) {
          window.curr_min_index = new_abs_min_index;
        }

        if( window.curr_max_index == prev_abs_max_index ) {
          window.curr_max_index = new_abs_max_index;
        }

        window.abs_min_index = new_abs_min_index;
        window.abs_max_index = new_abs_max_index;

        if( data.length == 0 ) {
          alert( "No timestamps found in data from server. Please ensure appropriate software is running and refresh this page." );
          return;
        }

        var length = data.length;

        $("#metrics_timestamp_range").slider( {
          range: true,
          min: window.abs_min_index,
          max: window.abs_max_index,
          values: [ window.curr_min_index, window.curr_max_index ],
          slide: handleChange,
          change: updateTimestampText
        } );

        updateTimestampText();
      },
      error: function () {
        alert( "Error retrieving timestamps to set slider boundaries." );
      }
    } );
  }

  function redrawGraph() {
    var metric_names = $("#metric_names").val() || [];

    if( metric_names.length == 0 ) {
      alert( "No metrics selected." );
      return;
    }

    var specified = false;
    if( ( window.curr_min_index != window.abs_min_index ) || ( window.curr_max_index != window.abs_max_index ) ) {
      specified = true;
    }
    var suffix = specified ? ( "/" + window.timestamps[ window.curr_min_index ] + "/" + window.timestamps[ window.curr_max_index ] ) : "/all";

    $("#static_link_placeholder").empty();

    $.ajax( {
      type: "GET",
      url: "/data/" + metric_names.join( "," ) + suffix,
      data: "",
      contentType: "application/json; charset=utf-8",
      dataType: "json",
      success: function ( data, status, xhr ) {

        var graph_data = [];
        var options = {
          xaxis: {
            mode: "time",
            tickLength: 5
          },
          grid: {
            hoverable: true,
            borderWidth: 3,
            mouseActiveRadius: 50,
            backgroundColor: { colors: ["#ffffff", "#EDF5FF"] },
            axisMargin: 20
          }
        };

        $.each( metric_names, function( index, value ) {
          var metric_name = value;
          var curr_graph = []
          $.each( data[ metric_name ], function( index, value ) {
            curr_graph.push( [ data.timestamps[ index ], value ] );
          } );

          graph_data.push( {
            label: metric_name,
            data: curr_graph,
            lines: {
              show: true
            }
          } );
        } );

        $.plot( "#placeholder", graph_data, options );
        $("#placeholder").UseTooltip();

        var static_url = "/graph/" + metric_names.join( "," ) + suffix;
        $("#static_link_placeholder").append( $( "<a/>" ).attr( "href", static_url ).attr( "target", "_blank" ).text( "Download as PNG" ) );
      },
      error: function () {
        alert( "Error getting data to populate graph." );
      }
    } );

  };

  function handleResize() {
    $(".graph_container").width( $(window).width() - $(".navigation").width() - 40 );
    $(".graph_container").height( $(window).height() - 40 );

    $("#name_filter").width( $("#metric_names").width() );
  }

  function refreshControls() {

    {
      window.selected_metric_names = $("#metric_names").val() || [];
      reloadStatNames();
    }

    {
      reloadSlider();
    }

  }

  function completeRefresh() {
    redrawGraph();
    refreshControls();
  }

  $("#metrics_redraw_partial").click( function () { 
    completeRefresh();
  } );

  $("#metrics_redraw_all").click( function () { 
    window.curr_min_index = window.abs_min_index;
    window.curr_max_index = window.abs_max_index;

    completeRefresh();
  } );

  $("#metrics_refresh").click( function () {
    if( $("#metrics_refresh").prop( "checked" ) ) {
      window.redraw = setInterval( function () {
        completeRefresh();
      }, 30000 );
    } else {
      clearInterval( window.redraw );
    }
  } );

  refreshControls();

} );

var previousPoint = null, previousLabel = null;

$.fn.UseTooltip = function () {
  $( this ).bind( "plothover", function ( event, pos, item ) {
    if ( item ) {
      if ( ( previousLabel != item.series.label ) || ( previousPoint != item.dataIndex ) ) {
        previousPoint = item.dataIndex;
        previousLabel = item.series.label;
        $("#tooltip").remove();

        var x = item.datapoint[0];
        var y = item.datapoint[1];

        var color = item.series.color;

        showTooltip( item.pageX,
                    item.pageY,
                    color,
                    "<strong>" + item.series.label + "</strong><br/>Value: <strong>" + y + "</strong><br/>Date: <strong>" + new Date( x ).toISOString() + "</strong>" );
      }
    } else {
      $("#tooltip").remove();
      previousPoint = null;
    }
  });
};

function showTooltip( x, y, color, contents ) {
  $( "<div id='tooltip'>" + contents + "</div>" ).css( {
    position: 'absolute',
    display: 'none',
    top: y - 40,
    left: x - 120,
    border: '2px solid ' + color,
    padding: '3px',
    'font-size': '9px',
    'border-radius': '5px',
    'background-color': '#fff',
    'font-family': 'Verdana, Arial, Helvetica, Tahoma, sans-serif',
    opacity: 0.9
  } ).appendTo( 'body' ).fadeIn( 200 );
}

$.fn.filterByText = function( textbox, selectSingleMatch ) {
  return this.each(function() {
    var select = this;
    var options = [];

    $( select ).find( 'option' ).each( function() {
      options.push( { value: $(this).val(), text: $(this).text() } );
    } );

    $( select ).data( 'options', options );

    $( textbox ).bind( 'change keyup', function() {
      var options = $( select ).empty().scrollTop( 0 ).data( 'options' );
      var search = $.trim( $(this).val() );
      var regex = new RegExp( search,'gi' );

      $.each( options, function( i ) {
        var option = options[i];
        if( option.text.match( regex ) !== null ) {
          $( select ).append( $( '<option/>' ).text( option.text ).val( option.value ) );
        }
      } );

      if( ( selectSingleMatch === true ) && ( $( select ).children().length === 1 ) ) {
        $( select ).children().get( 0 ).selected = true;
      }
    } );
  } );
};

