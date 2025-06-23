PayrollSmart: 
============

A contract that automates payroll and contractor payments on Stacks via a robust Clarity smart contract

Table of Contents
-----------------

-   Introduction

-   Features

-   Contract Details

    -   Error Codes

    -   Constants

    -   Data Structures

    -   Public Functions

    -   Private Functions

-   Deployment

-   Usage

-   Security Considerations

-   Contributing

-   License

-   Related Projects

Introduction
------------

`PayrollSmart` is a robust Clarity smart contract designed to automate and manage employee payroll and contractor payments on the Stacks blockchain. It incorporates essential features like role-based access control, customizable payment scheduling, and secure fund management, providing a transparent and efficient solution for decentralized payment systems.

This contract ensures that only authorized personnel can manage payroll, funds are disbursed according to predefined schedules, and all transactions are recorded for auditability.

Features
--------

-   **Automated Payroll**: Schedule and process recurring payments for full-time, part-time, and contract employees.

-   **Role-Based Access Control**: Securely manage contract operations with permissions for the contract owner and authorized administrators.

-   **Flexible Payment Frequencies**: Supports weekly, bi-weekly, and monthly payment cycles.

-   **Secure Fund Management**: Funds are held within the contract, with strict controls over deposits and disbursements.

-   **Payment History**: Maintains a detailed audit trail of all processed payments.

-   **Emergency Pause Mechanism**: The contract owner can pause payments in emergencies to prevent unauthorized transactions.

-   **Employee Management**: Register, activate, and deactivate employee records, tracking their salary, payment history, and active status.

-   **Batch Payments**: Efficiently process payments for multiple employees in a single transaction, with detailed results and accounting.

Contract Details
----------------

### Error Codes

The contract defines specific error codes to provide clear feedback on operation failures:

-   `u100`: `ERR-OWNER-ONLY` - Only the contract owner can perform this action.

-   `u101`: `ERR-NOT-FOUND` - The requested entity (e.g., employee) was not found or is inactive.

-   `u102`: `ERR-UNAUTHORIZED` - The caller is not authorized to perform this action.

-   `u103`: `ERR-INSUFFICIENT-FUNDS` - The contract has insufficient funds to complete the payment.

-   `u104`: `ERR-INVALID-AMOUNT` - An invalid amount (e.g., zero or negative) was provided.

-   `u105`: `ERR-ALREADY-EXISTS` - An entity with the given ID already exists.

-   `u106`: `ERR-PAYMENT-NOT-DUE` - Payment for the employee is not yet due.

-   `u107`: `ERR-ALREADY-PAID` - (Currently unused but reserved for future functionality).

### Constants

-   `CONTRACT-OWNER`: The principal address that deployed the contract.

-   `EMPLOYEE-TYPE-FULL-TIME`: `u1` (Represents a full-time employee).

-   `EMPLOYEE-TYPE-PART-TIME`: `u2` (Represents a part-time employee).

-   `EMPLOYEE-TYPE-CONTRACTOR`: `u3` (Represents a contractor).

-   `WEEKLY-BLOCKS`: `u1008` (Approximately 1 week in Stacks blocks).

-   `BIWEEKLY-BLOCKS`: `u2016` (Approximately 2 weeks in Stacks blocks).

-   `MONTHLY-BLOCKS`: `u4320` (Approximately 1 month in Stacks blocks).

### Data Structures

#### Maps

-   `employees`: A map storing comprehensive details for each employee.

    -   `employee-id`: `uint` (Unique identifier for the employee).

    -   `wallet-address`: `principal` (The employee's wallet address).

    -   `employee-type`: `uint` (Type of employee: full-time, part-time, contractor).

    -   `salary-amount`: `uint` (The amount to be paid per payment cycle).

    -   `payment-frequency`: `uint` (The block interval between payments).

    -   `last-payment-block`: `uint` (The block height of the last successful payment).

    -   `total-paid`: `uint` (Cumulative amount paid to the employee).

    -   `is-active`: `bool` (Indicates if the employee is currently active for payments).

    -   `start-date`: `uint` (The block height when the employee was registered).

-   `payment-history`: A map storing a record of each processed payment.

    -   `payment-id`: `uint` (Unique identifier for the payment record).

    -   `employee-id`: `uint` (The ID of the employee who received the payment).

    -   `amount`: `uint` (The amount paid in this transaction).

    -   `payment-block`: `uint` (The block height when the payment was made).

    -   `payment-type`: `(string-ascii 20)` (Description of the payment type, e.g., "regular-salary").

-   `authorized-admins`: A map to store `principal` addresses that are authorized administrators (besides the contract owner).

#### Variables

-   `contract-balance`: `uint` (The current balance of STX tokens held by the contract).

-   `next-employee-id`: `uint` (A counter for generating new employee IDs).

-   `next-payment-id`: `uint` (A counter for generating new payment history IDs).

-   `total-employees`: `uint` (The total count of active employees).

-   `monthly-payroll-budget`: `uint` (Tracks the total amount paid out in a conceptual "month" for reporting).

-   `contract-paused`: `bool` (A flag indicating if the contract's payment operations are paused).

### Public Functions

#### `(add-funds (amount uint))`

Allows the contract owner or an authorized administrator to deposit STX tokens into the contract's balance. These funds are used for payroll.

-   **Parameters**:

    -   `amount`: `uint` - The amount of STX tokens to deposit.

-   **Returns**: `(ok uint)` on success, `(err uint)` on failure (e.g., `ERR-UNAUTHORIZED`, `ERR-INVALID-AMOUNT`).

#### `(register-employee (wallet-address principal) (employee-type uint) (salary-amount uint) (payment-frequency uint))`

Registers a new employee with their payment details. Only authorized personnel can register employees.

-   **Parameters**:

    -   `wallet-address`: `principal` - The Stacks address of the employee.

    -   `employee-type`: `uint` - The type of employee (e.g., `EMPLOYEE-TYPE-FULL-TIME`).

    -   `salary-amount`: `uint` - The salary amount to be paid per cycle.

    -   `payment-frequency`: `uint` - The payment frequency in blocks (e.g., `WEEKLY-BLOCKS`).

-   **Returns**: `(ok uint)` (the new `employee-id`) on success, `(err uint)` on failure.

#### `(process-payment (employee-id uint))`

Processes a single payment for a specified employee if their payment is due and funds are available.

-   **Parameters**:

    -   `employee-id`: `uint` - The ID of the employee to pay.

-   **Returns**: `(ok uint)` (the `payment-amount`) on success, `(err uint)` on failure (e.g., `ERR-NOT-FOUND`, `ERR-INSUFFICIENT-FUNDS`, `ERR-PAYMENT-NOT-DUE`).

#### `(deactivate-employee (employee-id uint))`

Deactivates an employee, preventing further payments to them.

-   **Parameters**:

    -   `employee-id`: `uint` - The ID of the employee to deactivate.

-   **Returns**: `(ok bool)` (`true`) on success, `(err uint)` on failure.

#### `(toggle-contract-pause)`

Allows the contract owner to pause or unpause the contract, halting or resuming all payment operations.

-   **Parameters**: None

-   **Returns**: `(ok bool)` (the new pause status) on success, `(err uint)` on failure.

#### `(batch-process-payments (employee-ids (list 50 uint)))`

Processes payments for a list of employees in a single transaction. It validates each payment and aggregates results.

-   **Parameters**:

    -   `employee-ids`: `(list 50 uint)` - A list of employee IDs to process payments for.

-   **Returns**: `(ok {total-employees-processed: uint, successful-payments: uint, total-amount-paid: uint, remaining-balance: uint, processing-block: uint})` on success, `(err uint)` on failure.

### Private Functions

These are helper functions used internally by the public functions and cannot be called directly from outside the contract.

-   `(is-authorized (caller principal))`: Checks if a given principal is the contract owner or an authorized administrator.

-   `(calculate-next-payment-block (last-payment uint) (frequency uint))`: Calculates the block height when the next payment for an employee is due.

-   `(is-valid-employee-type (emp-type uint))`: Validates if the provided employee type is one of the recognized types.

-   `(is-payment-due (employee-id uint))`: Checks if payment is currently due for a specific employee based on their last payment and frequency.

-   `(calculate-total-payment-amount (employee-id uint) (acc uint))`: Helper for batch payments to sum up the total amount needed.

-   `(process-single-payment (employee-id uint))`: Helper for batch payments to attempt processing a single employee's payment.

-   `(is-payment-successful (payment-result (optional uint)))`: Helper for batch payments to determine if a sub-payment was successful.

-   `(sum-successful-payments (payment-result (optional uint)) (acc uint))`: Helper for batch payments to sum successful payment amounts.

Deployment
----------

This contract is written in Clarity and intended for deployment on the Stacks blockchain. You would typically deploy it using a Stacks-compatible wallet or development environment, such as the Stacks CLI or a web-based IDE like Clarinet.

Ensure that the deploying address (`tx-sender`) is the intended `CONTRACT-OWNER` as defined in the contract, as this address will have privileged control over key functionalities.

Usage
-----

Once deployed, the `PayrollSmart` contract can be interacted with via Clarity transactions:

1.  **Fund the Contract**: The `CONTRACT-OWNER` or an `authorized-admin` must first deposit STX tokens using the `add-funds` function.

2.  **Register Employees**: Use `register-employee` to add new employees, specifying their wallet address, type, salary, and payment frequency.

3.  **Process Payments**:

    -   For individual payments, call `process-payment` with the `employee-id`.

    -   For multiple payments, use `batch-process-payments` with a list of `employee-id`s.

    -   Payments will only be successful if they are due and the contract has sufficient funds.

4.  **Manage Employees**: Use `deactivate-employee` to stop payments to an employee.

5.  **Emergency Control**: The `CONTRACT-OWNER` can `toggle-contract-pause` to temporarily halt all payment disbursements.

Security Considerations
-----------------------

-   **Role-Based Access**: Critical functions are restricted to the `CONTRACT-OWNER` and `authorized-admins`. Ensure that these keys are kept secure.

-   **Emergency Pause**: The `toggle-contract-pause` function provides a failsafe in case of unforeseen issues or vulnerabilities, allowing payments to be halted promptly.

-   **Sufficient Funds**: The contract explicitly checks for `ERR-INSUFFICIENT-FUNDS` before any payment, preventing failed transactions due to an empty contract balance.

-   **Payment Due Checks**: Payments are only processed if they are genuinely due, preventing double payments within a payment cycle.

Contributing
------------

Contributions to `PayrollSmart` are welcome! If you have suggestions for improvements, bug fixes, or new features, please follow these steps:

1.  Fork the repository (if this were a GitHub project).

2.  Create a new branch for your feature or bug fix.

3.  Implement your changes and write tests.

4.  Ensure all existing tests pass.

5.  Submit a pull request with a clear description of your changes.

License
-------

This contract is released under the MIT License.

```
MIT License

Copyright (c) 2025 Ayomikun Akinseinde

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```

Related Projects
----------------

-   **Clarity Language**: The programming language used for this smart contract.

-   **Stacks Blockchain**: The blockchain platform where this contract operates.

-   **Clarinet**: The Clarity development environment for testing and deploying Clarity contracts.

-   **Decentralized Autonomous Organizations (DAOs)**: Concepts from DAOs for governance and treasury management could extend this contract's capabilities.
