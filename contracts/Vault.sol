// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Escapable.sol";

/**
 * @title Vault
 * @author Ghadi Mhawej
 **/

contract Vault is Escapable {
    /// @dev `Payment` is a public structure that describes the details of each payment
    struct Payment {
        string name; // What is the purpose of this payment
        bytes32 ref; // Reference of the payment.
        address spender; // Who is sending the funds
        uint256 earliestPayTime; // The earliest a payment can be made (Unix Time)
        bool canceled; // If True then the payment has been canceled
        bool paid; // If True then the payment has been paid
        address payable recipient; // Who is receiving the funds
        uint256 amount; // The amount of wei sent in the payment
        uint256 securityGuardDelay; // The seconds `securityGuard` can delay payment
    }

    Payment[] public authorizedPayments;

    address public securityGuard;
    uint256 public absoluteMinTimeLock;
    uint256 public timeLock;
    uint256 public maxSecurityGuardDelay;

    /// @dev The whitelisted addresses allowed to set up && receive payments from this vault
    mapping(address => bool) public allowedSpenders;

    // @dev Events Definition
    event PaymentAuthorized(
        uint256 indexed idPayment,
        address indexed recipient,
        uint256 amount
    );
    event PaymentExecuted(
        uint256 indexed idPayment,
        address indexed recipient,
        uint256 amount
    );
    event PaymentCanceled(uint256 indexed idPayment);
    event EtherReceived(address indexed from, uint256 amount);
    event SpenderAuthorization(address indexed spender, bool authorized);

    // @dev The address assigned the role of `securityGuard` is the only addresses that can call a function with this modifier
    modifier onlySecurityGuard() {
        require(
            _msgSender() == securityGuard,
            "Vault: the caller is not the securityGuard"
        );
        _;
    }

    // @dev resticts access to only allowed spenders
    modifier onlyAllowedSpender() {
        require(
            allowedSpenders[_msgSender()],
            "Vault: the caller is not an allowed spender"
        );
        _;
    }

    /// @notice constructor
    /// @param _escapeHatchCaller The address of a trusted account or contract to send the ether in this contract
    /// @param _escapeHatchDestination The address of a safe location to send the ether held in this contract to
    /// @param _absoluteMinTimeLock The minimum number of seconds `timelock` can be set to, if set to 0 the `owner` can remove the `timeLock` completely
    /// @param _timeLock Initial number of seconds that payments are delayed after they are authorized (a security precaution)
    /// @param _securityGuard Address that will be able to delay the payments beyond the initial timelock requirements; can be set to 0x0 to remove the `securityGuard` functionality
    /// @param _maxSecurityGuardDelay The maximum number of seconds in total that `securityGuard` can delay a payment so that the owner can cancel the payment if needed
    constructor(
        address _escapeHatchCaller,
        address payable _escapeHatchDestination,
        uint256 _absoluteMinTimeLock,
        uint256 _timeLock,
        address _securityGuard,
        uint256 _maxSecurityGuardDelay
    ) Escapable(_escapeHatchCaller, _escapeHatchDestination) {
        absoluteMinTimeLock = _absoluteMinTimeLock;
        timeLock = _timeLock;
        securityGuard = _securityGuard;
        maxSecurityGuardDelay = _maxSecurityGuardDelay;
    }

    /// @notice Returns the total number of authorized payments in this contract
    function numberOfAuthorizedPayments() public view returns (uint256) {
        return authorizedPayments.length;
    }

    /// @notice The fall back function is called whenever ether is sent to this
    ///  contract
    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    /// @notice `allowedSpenders` create a new `Payment`
    /// @param _name Brief description of the payment that is authorized
    /// @param _reference External reference of the payment
    /// @param _recipient Destination of the payment
    /// @param _amount Amount to be paid in wei
    /// @param _paymentDelay Number of seconds the payment is to be delayed; if this value is below `timeLock` then the `timeLock` determines the delay
    /// @return The Payment ID number for the new authorized payment
    function authorizePayment(
        string memory _name,
        bytes32 _reference,
        address payable _recipient,
        uint256 _amount,
        uint256 _paymentDelay
    ) public onlyAllowedSpender returns (uint256) {
        require(_paymentDelay < 10**18, "Vault: paymentDelay overflow risk");

        uint256 idPayment = authorizedPayments.length;

        Payment memory p = authorizedPayments[idPayment];
        p.spender = _msgSender();

        // Determines the earliest the recipient can receive payment (Unix time)
        p.earliestPayTime = _paymentDelay >= timeLock
            ? block.timestamp + _paymentDelay
            : block.timestamp + timeLock;

        p.recipient = _recipient;
        p.amount = _amount;
        p.name = _name;
        p.ref = _reference;

        authorizedPayments.push(p);

        emit PaymentAuthorized(idPayment, p.recipient, p.amount);
        return idPayment;
    }

    /// @notice  Called by recipient of a payment to receive the ether after the earliestPayTime` has passed
    /// @param _idPayment The payment ID to be executed
    function collectAuthorizedPayment(uint256 _idPayment) public nonReentrant {
        require(
            _idPayment <= authorizedPayments.length,
            "Vault: Payment doesn't exist"
        );

        Payment memory p = authorizedPayments[_idPayment];

        require(
            _msgSender() == p.recipient,
            "Vault: caller is not the recipient"
        );
        require(allowedSpenders[p.spender], "Vault: Spender is not authorized");
        require(
            block.timestamp > p.earliestPayTime,
            "Vault: Not allowed to spend yet"
        );
        require(!(p.canceled), "Vault: Payment was cancelled");
        require(!(p.paid), "Vault: Payment already paid");
        require(address(this).balance > p.amount, "Vault: Not enough balance");

        authorizedPayments[_idPayment].paid = true;

        p.recipient.transfer(p.amount);

        emit PaymentExecuted(_idPayment, p.recipient, p.amount);
    }

    /// @notice Called by Security Guard to delay a payment for a set number of seconds
    /// @param _idPayment ID of the payment to be delayed
    /// @param _delay The number of seconds to delay the payment
    function delayPayment(uint256 _idPayment, uint256 _delay)
        public
        onlySecurityGuard
    {
        require(
            _idPayment <= authorizedPayments.length,
            "Vault: Payment doesn't exist"
        );

        require(_delay < 10**18, "Vault: paymentDelay overflow risk");

        require(
            !(authorizedPayments[_idPayment].canceled),
            "Vault: Payment was cancelled"
        );
        require(
            !(authorizedPayments[_idPayment].paid),
            "Vault: Payment already paid"
        );
        require(
            authorizedPayments[_idPayment].securityGuardDelay + _delay <
                maxSecurityGuardDelay,
            "Vault: delay time too big"
        );

        authorizedPayments[_idPayment].securityGuardDelay += _delay;
        authorizedPayments[_idPayment].earliestPayTime += _delay;
    }

    /// @notice Called by owner to cancel a payment
    /// @param _idPayment ID of the payment to be canceled.
    function cancelPayment(uint256 _idPayment) public onlyOwner {
        require(
            _idPayment <= authorizedPayments.length,
            "Vault: Payment doesn't exist"
        );

        require(
            !(authorizedPayments[_idPayment].canceled),
            "Vault: Payment was cancelled"
        );
        require(
            !(authorizedPayments[_idPayment].paid),
            "Vault: Payment already paid"
        );
        authorizedPayments[_idPayment].canceled = true;
        emit PaymentCanceled(_idPayment);
    }

    /// @notice Called by owner to add an address to the allowedSpenders whitelist
    /// @param _spender The address of the contract being authorized
    function authorizeSpender(address _spender) public onlyOwner {
        allowedSpenders[_spender] = true;
        emit SpenderAuthorization(_spender, true);
    }

    /// @notice Called by owner to remove an address to the allowedSpenders whitelist
    /// @param _spender The address of the contract being removed
    function removeSpender(address _spender) public onlyOwner {
        allowedSpenders[_spender] = false;
        emit SpenderAuthorization(_spender, false);
    }

    /// @notice Called by owner to set new address of security guard
    /// @param _newSecurityGuard Address of the new security guard
    function setSecurityGuard(address _newSecurityGuard) public onlyOwner {
        securityGuard = _newSecurityGuard;
    }

    /// @notice owner can change timeLock; the new `timeLock` cannot be  lower than `absoluteMinTimeLock`
    /// @param _newTimeLock Sets the new minimum default `timeLock` in seconds; pending payments maintain their `earliestPayTime`
    function setTimelock(uint256 _newTimeLock) public onlyOwner {
        require(
            _newTimeLock > absoluteMinTimeLock,
            "Vault: _newTimeLock should be higher than absoluteMinTimeLock"
        );
        timeLock = _newTimeLock;
    }

    /// @notice owner can change the maximum number of seconds`securityGuard` can delay a payment
    /// @param _maxSecurityGuardDelay The new maximum delay in seconds
    function setMaxSecurityGuardDelay(uint256 _maxSecurityGuardDelay)
        public
        onlyOwner
    {
        maxSecurityGuardDelay = _maxSecurityGuardDelay;
    }
}
