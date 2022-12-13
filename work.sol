// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

contract BBB {
    /*********************************************************************************************
     ************************************   VARIABLES     ****************************************
     *********************************************************************************************/

    uint256 constant REWARD_RATE = 50;
    // 関数のaddressは適当です
    address constant BBBToken = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    //@note コンストラクターのように動く
    address owner = msg.sender;
    address[] approvedTokens; /// JPYC, USDC, USDTのみがownerからapproveされます
    address[] whitelist;
    //@note user-address => token-address => info
    mapping(address => mapping(address => DepostInfo)) depositAmt;

    /*********************************************************************************************
     ************************************     STRUCT     ****************************************
     *********************************************************************************************/

    struct DepostInfo {
        uint256 lastTime; /// 32 bytes
        uint256 amount; /// 32 bytes
    }

    struct TransferInfo {
        //@note boolに修正
        bool isETH; /// 32 bytes
        uint256 amount; /// 32 bytes
        address token; /// 20 bytes
        address from; /// 20 bytes
        address to; /// 20 bytes
    }

    /*********************************************************************************************
     *********************************   OWNER FUNCTIONS     *************************************
     *********************************************************************************************/

    /// @notice  approvedTokens配列にtokenを使いするために使用します
    /// @dev     ownerだけが実行できます
    // @audit 重複チェックがない。消すことも出来ない
    function addApprovedTokens(address _token) private {
        if (msg.sender != owner) revert();
        approvedTokens.push(_token);
    }

    /*********************************************************************************************
     *******************************   VIEW | PURE FUNCTIONS     *********************************
     *********************************************************************************************/

    /// @notice
    /// @dev     Can call only owner //@note オーナー以外も実行出来る
    /// @return reward //@note コメントを入れないとエラー
    function getReward(address token) public view returns (uint256 reward) {
        uint256 amount = depositAmt[msg.sender][token].amount;
        uint256 lastTime = depositAmt[msg.sender][token].lastTime;
        reward = (REWARD_RATE / (block.timestamp - lastTime)) * amount;
    }

    function _isXXX(address _token, address[] memory _xxx)
        private
        pure
        returns (bool)
    {
        uint256 length = _xxx.length;
        for (uint256 i; i < length; ) {
            if (_token == _xxx[i]) return true;
            // @audit オーバーフローする可能性がある
            unchecked {
                ++i;
            }
        }
        return false;
    }

    /*********************************************************************************************
     *********************************   PUBLIC FUNCTIONS     ************************************
     *********************************************************************************************/
    //@audit 重複チェックがない
    function addWhitelist(address _token) public {
        if (!_isXXX(_token, approvedTokens)) revert();
        whitelist.push(_token);
    }

    // @audit payableにしないとETHを受け取れない
    function deposit(
        uint256 _amount,
        address _token,
        bool _isETH
    ) public payable {
        if (!_isXXX(_token, whitelist)) revert();
        DepostInfo memory depositInfo;
        TransferInfo memory info = TransferInfo({
            isETH: _isETH,
            token: _token,
            from: msg.sender,
            amount: _amount,
            to: address(this)
        });

        _tokenTransfer(info);
        // @audit uint40?
        depositInfo.lastTime = uint40(block.timestamp);
        // @audit 追加depositすると上書きされてしまう
        depositInfo.amount = _amount;
        depositAmt[msg.sender][_token] = depositInfo;
    }

    function withdraw(
        address _to,
        uint256 _amount,
        bool _isETH,
        address _token
    ) public {
        if (!_isXXX(_token, whitelist)) revert();
        TransferInfo memory info = TransferInfo({
            isETH: _isETH,
            token: _token,
            from: address(this),
            amount: _amount,
            to: _to
        });
        uint256 canWithdrawAmount = depositAmt[msg.sender][_token].amount;
        require(info.amount < canWithdrawAmount, "ERROR");
        // @audit なんのため？ withdrawした分だけamountを減らす処理が無い
        canWithdrawAmount = 0;
        _tokenTransfer(info);
        uint256 rewardAmount = getReward(_token);
        // @audit rewardAmountが0の場合の考慮が無い
        IERC20(BBBToken).transfer(msg.sender, rewardAmount);
    }

    /*********************************************************************************************
     *********************************   PRIVATE FUNCTIONS     ***********************************
     *********************************************************************************************/
    //  @audit reentrancy?
    function _tokenTransfer(TransferInfo memory _info) private {
        if (_info.isETH) {
            (bool success, ) = _info.to.call{value: _info.amount}("");
            require(success, "Failed");
        } else {
            IERC20(_info.token).transferFrom(
                _info.from,
                _info.to,
                _info.amount
            );
        }
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}
