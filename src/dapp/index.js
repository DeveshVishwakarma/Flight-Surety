
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;
    let available_flights = [];

    let contract = new Contract('localhost', () => {

        let self = this;
    
        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error ? error : "", "Operation Status: " + result);

            displayOperationalStatus([{
                label: 'Operation Status',
                error: error,
                value: result
            }]);

            displayFlightplan(available_flights, fetchFlightStatusCallback, registerFlightCallback);
            contract.insuranceBalance(insuranceBalanceCallback);
        });
    

        // User-submitted transaction
        DOM.elid('passenger-withdraw').addEventListener('click', () => {
            contract.passengerWithdraw(function () {
                contract.insuranceBalance(insuranceBalanceCallback);
            });
        });

        contract.oracleReport(result => {
            console.log(JSON.stringify(result));
        });

        available_flights = [{
                time: "00:20",
                timestamp: Math.floor(Date.now() / 1000),
                target: "Delhi",
                fn: "IN294",
                airline: contract.owner,
                status: "0"
            },
            {
                time: "12:30",
                timestamp: Math.floor(Date.now() / 1000),
                target: "Mumbai",
                fn: "IN334",
                airline: contract.owner,
                status: "0"
            },
            {
                time: "08:00",
                timestamp: Math.floor(Date.now() / 1000),
                target: "Bangalore",
                fn: "IN129",
                airline: contract.owner,
                status: "0"
            },
            {
                time: "22:45",
                timestamp: Math.floor(Date.now() / 1000),
                target: "Chennai",
                fn: "IN768",
                airline: contract.owner,
                status: "0"
            },
            {
                time: "06:50",
                timestamp: Math.floor(Date.now() / 1000),
                target: "Ahemdabad",
                fn: "IN543",
                airline: contract.owner,
                status: "0"
            }
        ];
    
        function resolveFlight(flightNumber) {
            for (let i = 0; i < available_flights.length; i++) {
                if (available_flights[i].fn === flightNumber) {
                    return available_flights[i];
                }
            }
            return null;
        }

        contract.flightStatusInfo(result => {
            console.log("Verified Flight: " + JSON.stringify(result));
            let updateFlight = resolveFlight(result.flight);
            if (updateFlight !== null) {
                updateFlight.status = result.status;
                let flight_row = DOM.elid("row_" + result.flight);
                displayUpdateFlightplanRow(flight_row, updateFlight, fetchFlightStatusCallback, registerFlightCallback);
            } else {
                console.log("Flight not found.");
            }

            contract.insuranceBalance(insuranceBalanceCallback);
        });
    });

    function registerFlightCallback(flight, value) {
        contract.registerFlight(resolveFlight(flight), value, () => {
            console.log("Flight registered for insurance: " + JSON.stringify(flight));
        })
    }

    function insuranceBalanceCallback(result) {
        displayBalance(result);
    }

    function fetchFlightStatusCallback(flight) {
        contract.fetchFlightStatus(resolveFlight(flight), (error, result) => {
            if (error) {
                console.log(error);
            } else {
                console.log(result)
            }
        });
    }

})();

function displayOperationalStatus(status) {
    let displayDiv = DOM.elid("display-wrapper-operational");
    displayDiv.innerHTML = "";

    let sectionOperationalStatus = DOM.section();
    sectionOperationalStatus.appendChild(DOM.h4('Operational Status: '));
    sectionOperationalStatus.appendChild(DOM.h5('Check if the contract is operational!'));
    status.map((result) => {
        let row = sectionOperationalStatus.appendChild(DOM.div({
            className: 'row'
        }));
        row.appendChild(DOM.div({
            className: 'col-sm-4 field'
        }, result.label));
        row.appendChild(DOM.div({
            className: 'col-sm-8 field-value'
        }, result.error ? String(result.error) : String(result.value)));
        sectionOperationalStatus.appendChild(row);
    })
    displayDiv.append(sectionOperationalStatus);
};

function displayBalance(value) {
    let divBalance = DOM.elid("passenger-balance");
    divBalance.innerHTML = value + ' ETH';
}

function displayUpdateFlightplanRow(row, flight, fetchFlightStatusCallback, registerFlightCallback) {

    function resolveStatusText(status_id) {
        switch (status_id) {
            case "0":
                return "Status: Unknown";
            case "10":
                return "Status: On Time";
            case "20":
                return "Status: Late Airline";
            case "30":
                return "Status: Later Weather";
            case "40":
                return "Status: Late Technical";
            case "50":
                return "Status: Late Other";
        }
        return "Status Not Available";
    }

    row.innerHTML = "";

    let dataElementId = flight.fn + '_value';
    
    row.appendChild(DOM.div({
        className: 'col-sm-1 field-value',
        style: {
            margin: 'auto 0 auto 0'
        }
    }, flight.time));

    row.appendChild(DOM.div({
        className: 'col-sm-1 field-value',
        style: {
            margin: 'auto 0 auto 0'
        }
    }, flight.fn));

    row.appendChild(DOM.div({
        className: 'col-sm-2 field-value',
        style: {
            margin: 'auto 0 auto 0'
        }
    }, flight.target));

    row.appendChild(DOM.div({
        className: 'col-sm-2 field',
        style: {
            margin: 'auto 0 auto 0',
            color: flight.status === "20" ? '#FF0000' : '#FFFFFF'
        }
    }, resolveStatusText(flight.status)));

    let editValue = DOM.input({
        id: dataElementId,
        className: 'field-value',
        style: {
            margin: 'auto 5px auto 30px',
            width: '40px',
            'text-align': 'center'
        },
        value: '0.8'
    });

    row.appendChild(editValue);

    row.appendChild(DOM.div({
        className: 'field-value',
        style: {
            margin: 'auto 0 auto 0',
            width: '40px'
        }
    }, "ETH"));

    let insuranceButton = DOM.button({
        className: 'btn ',
        style: {
            margin: '5px'
        }
    }, "Buy Flight Insurance");

    insuranceButton.addEventListener('click', () => {
        registerFlightCallback(flight.fn, DOM.elid(dataElementId).value);
    });
    row.appendChild(insuranceButton);

    let fetchStatusButton = DOM.button({
        className: 'btn btn-primary',
        style: {
            margin: 'auto 0 auto 40px'
        }
    }, "Fetch Flight Status");
    fetchStatusButton.addEventListener('click', () => {
        fetchFlightStatusCallback(flight.fn);
    });
    row.appendChild(fetchStatusButton);

}

function displayFlightplan(flights, fetchFlightStatusCallback, registerFlightCallback) {
    let displayDiv = DOM.elid("display-wrapper");
    displayDiv.innerHTML = "";

    // Display the currently Available Flights
    let sectionFlightPlan = DOM.section();
    sectionFlightPlan.appendChild(DOM.h2("Flight Plan"));

    if (flights !== null) {
        sectionFlightPlan.appendChild(DOM.h5("Currently Available Flights: "));

        let firstRow = sectionFlightPlan.appendChild(DOM.div({
            id: 0,
            className: 'row'
        }));

        firstRow.appendChild(DOM.div({
            className: 'col-sm-1 field-value',
            style: {
                margin: 'auto 0 auto 0'
            }
        }, "Time: "));

        firstRow.appendChild(DOM.div({
            className: 'col-sm-1 field-value',
            style: {
                margin: 'auto 0 auto 0'
            }
        }, "Flight code: "));

        firstRow.appendChild(DOM.div({
            className: 'col-sm-3 field-value',
            style: {
                margin: 'auto 0 auto 0'
            }
        }, "Destination: "));

        firstRow.appendChild(DOM.div({
            className: 'col-sm-1 field-value',
            style: {
                margin: 'auto 0 auto 0'
            }
        }, "Flight Status: "));

        firstRow.appendChild(DOM.div({
            className: 'col-sm-1 field-value',
            style: {
                margin: 'auto 0 auto 0'
            }
        }, "Insurance Price: "));
        
        flights.map((flight) => {
            let row_id = 'row_' + flight.fn;

            let row = sectionFlightPlan.appendChild(DOM.div({
                id: row_id,
                className: 'row'
            }));
            displayUpdateFlightplanRow(row, flight, fetchFlightStatusCallback, registerFlightCallback);

            sectionFlightPlan.appendChild(row);
        })

    } else {
        sectionFlightPlan.appendChild(DOM.h5("Loading all the Available Flights..."));
    }

    displayDiv.append(sectionFlightPlan);
}





