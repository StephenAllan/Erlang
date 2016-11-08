% 
% A bank and client simulation program.
% 
% @author Stephen Allan (swa9846)
% @version October 28th, 2016
%


-module(project4).

-compile(export_all).


% 
% Generates a random number between the lower and upper bounds, inclusive.
% 
% @param LowerBound - The smallest number which can be generated
% @param UpperBound - The largest number which can be generated
% @return The randomly generated number
%
generateRandomInt(LowerBound, UpperBound) ->
    random:seed(erlang:monotonic_time()),
    random:uniform(UpperBound - (LowerBound-1)) + (LowerBound-1).


% 
% Generates a list of random numbers of the specified size, where all elements are between the lower and upper bounds, inclusive.
% 
% @param Size - The size of the generated list
% @param LowerBound - The smallest number which can be generated
% @param UpperBound - The largest number which can be generated
% @return The list of randomly generated numbers
%
generateRandomIntList(Size, LowerBound, UpperBound) ->
    lists:map(
        fun(_) ->
            generateRandomInt(LowerBound, UpperBound)
        end,
        lists:seq(1, Size)
    ).


% 
% Forces the calling process to sleep for a random duration between 500 and 1500 milliseconds.
% 
sleep() ->
    receive
        after generateRandomInt(500, 1500) -> ok
    end.


% 
% Receives messages from client processes which update and request the status of the balance.
% Keeps track of how many clients are connected at one time.
% When no more clients are connected, prints out the remaining balance and terminates.
% 
% @param Balance - The current balance in the bank
% @param NumClients - The number of currently connected client processes
% 
bank(Balance, 0) ->
    io:format("~w: Bank closing... Final Balance is ~w.~n", [self(), Balance]);

bank(Balance, NumClients) ->
    receive
        goodbye -> bank(Balance, NumClients-1);
        
        {ClientID, balance} ->
            ClientID ! Balance,
            bank(Balance, NumClients);
        
        {ClientID, Amount} ->
            NewBalance = Balance + Amount,
            if
                NewBalance >= 0 ->
                    ClientID ! {Amount, NewBalance, yes},
                    bank(NewBalance, NumClients);
                true ->
                    ClientID ! {Amount, Balance, no},
                    bank(Balance, NumClients)
            end
    end.


% 
% Client processes communicate with the bank process.
% Clients process each number in their given list, sending it to the bank to make a transaction.
% Negative integer values withdral, positive values deposit.
% Clients wait for a response from the bank, and then pause before sending their next transaction.
% Every five transactions, clients request the current balance from the bank.
% When all transactions are complete, clients notify the bank and terminate.
%
% @param List - The list of integers to send to the bank
% @param Count - The number used to keep track of when to request the balance
% 
client([], _) ->
    io:format("~w: Client ~w closing.~n", [self(), self()]), 
    bank ! goodbye;

client(List, 0) ->
    bank ! {self(), balance},
    receive
        Balance ->
            io:format("~w: Balance of ~w was received.~n", [self(), Balance])
    end,
    sleep(),
    client(List, 5);

client([Head|Tail], Count) ->
    bank ! {self(), Head},
    receive
        {Requested, Balance, Occurred} ->
            case Occurred of
                yes -> io:format("~w: Received the balance of ~w from the bank after a successful transaction request of ~w.~n", [self(), Balance, Requested]);
                _Else -> io:format("~w: Received the balance of ~w from the bank after a failed transaction request of ~w.~n", [self(), Balance, Requested])
            end
    end,
    sleep(),
    client(Tail, Count-1).


% 
% Spawns the specified amount of client processes.
%
% @param Count - The number of client processes to create 
% 
spawnClients(0) -> ok;

spawnClients(Count) ->
    spawn(project4, client, [generateRandomIntList(generateRandomInt(10, 20), -100, 100), 5]),
    spawnClients(Count - 1).


% 
% Program entry point.
% Generates a random number for the number of clients and the bank's starting balance.
% Spawns the bank process and a process which creates all of the clients.
% 
start() ->
    Balance = generateRandomInt(2000, 3000),
    NumClients = generateRandomInt(2, 10),
    io:format("Opening bank with a balance of ~w and ~w customers.~n", [Balance, NumClients]),
    register(bank, spawn(project4, bank, [Balance, NumClients])), 
    spawn(project4, spawnClients, [NumClients]).

