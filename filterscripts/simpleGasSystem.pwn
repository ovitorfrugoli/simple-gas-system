/*******************************************************************************
* FILENAME :        simpleGasSystem.pwn
*
* DESCRIPTION :
*       Filterscript main archive.
*
* NOTES :
*       -
*
*
*/


/*
 * I N C L U D E S
 ******************************************************************************
 */
#include <a_samp>
#include <zcmd>

/*
 * D E F I N I T I O N S
 ******************************************************************************
 */

/**
* Macros Utilizados
*/
native IsValidVehicle(vehicleid);

forward TimerLoadVehicleFuel();
forward RefuellingVehicle(playerid, carID, amount, gasValue);

static stock stringFormat[256];

#if !defined isnull
	#define isnull(%1) ((!(%1[0])) || (((%1[0]) == '\1') && (!(%1[1]))))
#endif

#if !defined SendClientMessageEx
	#define SendClientMessageEx(%0,%1,%2,%3) format(stringFormat, sizeof(stringFormat),%2,%3) && SendClientMessage(%0, %1, stringFormat)
#endif

#define PlayerTextDrawSetStringFormat(%0,%1,%2,%3) \
    format(stringFormat, sizeof(stringFormat), %2, %3) && \
    PlayerTextDrawSetString(%0, PlayerText:%1, stringFormat)

const

	/**
	* Cores Utilizadas
	*/
	COLOR_RED		= 0xE84F33AA,
	COLOR_GREEN		= 0x9ACD32AA,
	COLOR_ANNOUNC   = 0x5BB006FF,
	COLOR_ORANGE    = 0xFF8B53FF,

	/**
	* Quantidade máxima de postos cadastrados na matriz.
	*/
	gasStationsMax  = 15,

	/**
	* Quantidade de quilômetros rodados.
	*/
	kmMax           = 12,

	/**
	* Tempo em milissegundos para abastecer o veículo.
	*/
	timeFuel        = 1500
;

/*
 * E N U M E R A T O R S
 ******************************************************************************
 */

/**
* ID das caixas de diálogo utilizadas.
*/
enum
{
	DIALOG_GAS_STATION_LIST,
	DIALOG_GAS_PRICE_LIST,
	DIALOG_GAS_CHANGE_PRICE,
	DIALOG_GAS_TO_FUEL
}

/**
* Enumerador para a matriz dos postos de gasolina.
*/
enum E_GAS_STATIONS
{
	E_GAS_STATION_NAME[26],
	E_GAS_STATION_VALUE,
	Float:E_GAS_STATION_POS_X,
	Float:E_GAS_STATION_POS_Y,
	Float:E_GAS_STATION_POS_Z
}

/**
* Enumerador para a Textdraw visualizada pelo jogador.
*/
enum E_TEXT_PRIVATE_VEHICLE_FUEL
{
    PlayerText:E_FUEL_BAR,
    PlayerText:E_FUEL_PERCENT
}

/*
 * V A R I A B L E S
 ******************************************************************************
 */
static

	/**
	* Matriz com os postos de gasolina.
	*/
	gasStations[gasStationsMax][E_GAS_STATIONS] = 
	{
		{"Idlewood (LS)", 10, 1939.1427,-1772.2169,13.3828},
		{"Mulholland (LS)", 10, 1008.0753,-938.1916,42.1797},
		{"Flint County", 10, -92.0782,-1176.0292,2.2054},
		{"Dillimore", 10, 653.6338,-559.4720,16.3359},
		{"MontGomery", 10, 1383.5737,457.3308,19.9710},
		{"Whetstone", 10, -1606.4407,-2715.2375,48.5391},
		{"Angel Pine", 10, -2245.4534,-2560.7139,31.9219},
		{"Julius Thruway South (LV)", 10, 2115.7349,927.3634,10.8203},
		{"Come-a-Lot (LV)", 10, 2639.4199,1099.4639,10.8203},
		{"The Emerald Isle (LV)", 10, 2198.3442,2474.5144,10.8203},
		{"Redsands West (LV)", 10, 1596.3252,2202.7283,10.8203},
		{"Bone Country", 10, 614.1276,1690.9031,6.9922},
		{"Tierra Robada", 10, -1477.6395,1866.1390,32.6398},
		{"El Quebrados", 10, -1328.2958,2676.1328,50.0625},
		{"Juniper Hill (SF)", 10, -2409.0969,975.6957,45.2969}
	},
	
	/**
	* Variáveis das dialogs para o jogador.
	*/
	playerGasStationsList[MAX_PLAYERS][gasStationsMax],
	adminGasStationsList[MAX_PLAYERS][gasStationsMax],
	playerinGasStation[MAX_PLAYERS],

	/**
	* Text3DLabel dos postos de gasolina.
	*/
	Text3D:gasStations3DText[gasStationsMax],

	/**
	* Variáveis utilizadas nos veículos.
	*/
	carFuel[MAX_VEHICLES],
	carMax[MAX_VEHICLES],
	Float:carVelocity[3],

	/**
	* Variável para controlar se o jogador está a visualizar a textdraw informativa da gasolina do veículo.
	*/
	bool:playerViewingVehicleFuel[MAX_PLAYERS],

	/**
	* Variável de controle da TextDraw utilizada para fixar bug das transparências.
	*/
    Text:textBugFix,

	/**
	* Variáveis das textdraws.
	*/
	Text:textGlobalVehicleFuel[2],
	PlayerText:textPrivateVehicleFuel[MAX_PLAYERS][E_TEXT_PRIVATE_VEHICLE_FUEL]
;

/*
 * N A T I V E 
 * C A L L B A C K S
 ******************************************************************************
 */

/**
 * Inicia o Filterscript.
 * 
 * @param                 Não possui parâmetros.
 * @return                1 caso verdadeiro.
 */
public OnFilterScriptInit()
{
	PrintSystemLoaded("simpleGasSystem");

	FixCreateTextDrawTransparency();

	LoadGasStation();

	SetTimer("TimerLoadVehicleFuel", 5000, false);

	CreateGlobalTDVehicleFuel();
	return 1;
}

/**
 * Ativada ao veículo ser destruído.
 * 
 * @param vehicleid       ID do veículo.
 * @param killerid        ID do 'destruidor' do veículo.
 * @return                1 caso verdadeiro.
 */
public OnVehicleDeath(vehicleid, killerid)
{

	carMax[vehicleid] = 0;
	carFuel[vehicleid] = 0;
	return 1;
}

/**
 * Ativada ao usuário conectar no servidor.
 * 
 * @param playerid       ID do jogador.
 * @return               1 caso verdadeiro.
 */
public OnPlayerConnect(playerid)
{

	FixShowTextDrawTransparency(playerid);

	ResetPlayerVariables(playerid);

	CreatePrivateTDVehicleFuel(playerid);
	return 1;
}

/**
 * Ativada ao usuário entrar em uma Checkpoint.
 * 
 * @param playerid       ID do jogador.
 * @return               1 caso verdadeiro.
 */
public OnPlayerEnterCheckpoint(playerid)
{

	DisablePlayerCheckpoint(playerid);
	return 1;
}

/**
 * Ativada a cada 30 segundos..
 * 
 * @param playerid       ID do jogador.
 * @return               1 caso verdadeiro.
 */
public OnPlayerUpdate(playerid)
{

	PlayerVehicleFuelCheck(playerid);
	return 1;
}

/**
 * Ativada se o estado do jogador é alterado.
 * 
 * @param playerid       ID do jogador.
 * @param newstate       Novo estado.
 * @param oldstate       Antigo estado.
 * @return               1 caso verdadeiro.
 */
public OnPlayerStateChange(playerid, newstate, oldstate)
{
	switch(newstate)
	{
		case PLAYER_STATE_DRIVER, PLAYER_STATE_PASSENGER:
		{
			if(!IsPlayerViewingVehicleFuel(playerid))
			{
				ShowPlayerVehicleFuel(playerid);
				return 1;			
			}
		}
	}

	switch(oldstate)
	{
		case PLAYER_STATE_DRIVER, PLAYER_STATE_PASSENGER:
		{
			if(IsPlayerViewingVehicleFuel(playerid))
				HidePlayerVehicleFuel(playerid);
		}
	}
	return 1;
}

/**
 * Ativada se uma tecla é pressionada.
 * 
 * @param playerid       ID do jogador.
 * @param newkeys        Novo estado.
 * @param oldkeys        Antigo estado.
 * @return               1 caso verdadeiro.
 */
public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if((newkeys & KEY_CROUCH) && !(oldkeys & KEY_CROUCH))
		PlayerFuelVehicle(playerid, false);	

	return 1;
}

/**
 * Aplica as funções de cada dialog selecionada.
 * 
 * @param playerid       ID do jogador.
 * @param dialogid       ID da caixa de diálogo.
 * @param response       Resposta da caixa de diálogo.
 * @param listitem       item de uma lista.
 * @param inputtext[]    Texto inserido.
 * @return               1 caso verdadeiro.
 */
public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch(dialogid)
	{
		case DIALOG_GAS_STATION_LIST:
		{

			if(!response)
				return SendClientMessage(playerid, COLOR_RED, "<!>{FFFFFF}Você optou por fechar o painel.");

			new gasID = playerGasStationsList[playerid][listitem];

			DisablePlayerCheckpoint(playerid);
			SetPlayerCheckpoint(playerid, gasStations[gasID][E_GAS_STATION_POS_X], gasStations[gasID][E_GAS_STATION_POS_Y], gasStations[gasID][E_GAS_STATION_POS_Z], 3.0);

			return SendClientMessage(playerid, COLOR_GREEN, "<!>{FFFFFF}Posto destacado em seu minimapa.");
		}

		case DIALOG_GAS_PRICE_LIST:
		{
			if(!response)
				return SendClientMessage(playerid, COLOR_RED, "<!>{FFFFFF}Você optou por fechar o painel.");

			new
				info[(103 + 5) + 1], caption[(23 + 26) + 1], 
				priceID = adminGasStationsList[playerid][listitem];
		
			adminGasStationsList[playerid][0] = priceID;

			format(caption, sizeof(caption), "Posto de Gasolina de %s", gasStations[priceID][E_GAS_STATION_NAME]);		 	
			format(info, sizeof(info), "O valor atual do litro da gasolina neste posto é %d\ndigite abaixo o novo valor do litro da gasolina.", gasStations[priceID][E_GAS_STATION_VALUE]);

			return ShowPlayerDialog(playerid, DIALOG_GAS_CHANGE_PRICE, DIALOG_STYLE_INPUT, caption, info, "Alterar", "Sair");
		}
		case DIALOG_GAS_CHANGE_PRICE:
		{
			if(!response)
				return SendClientMessage(playerid, COLOR_RED, "<!>{FFFFFF}Você optou por não alterar o valor da gasolina.");
		
			new 
				gasInfo = adminGasStationsList[playerid][0],
				price = strval(inputtext),
				info[(71 + 26 + 3) + 1];

			format(info, sizeof(info), "[POSTO] O preço do litro da gasolina do posto %s foi alterada para $%d!", gasStations[gasInfo][E_GAS_STATION_NAME], price);
			SendClientMessageToAll(COLOR_ANNOUNC, info);

			gasStations[gasInfo][E_GAS_STATION_VALUE] = price;
			LoadGasStation(gasInfo);
			return 1;
		}
		case DIALOG_GAS_TO_FUEL:
		{
			if(!response)
				return SendClientMessage(playerid, COLOR_RED, "<!>{FFFFFF}Você optou por não abastecer seu veículo.");

			new gasID = playerinGasStation[playerid],
				amount = strval(inputtext),
				money = GetPlayerMoney(playerid),
				carID = GetPlayerVehicleID(playerid),
				gasValue = (amount * gasStations[gasID][E_GAS_STATION_VALUE]),
				actualGas = carFuel[carID]
				;

			if(money < gasValue)
				return SendClientMessage(playerid, COLOR_RED, "<!>{FFFFFF}Você não tem dinheiro o suficiente para abastecer seu veículo.");

			if(!(0 < amount <= 100))
				return SendClientMessage(playerid, COLOR_RED, "<!>{FFFFFF}Quantidade de litros inválida.");

			if(amount + actualGas > 100)
    			amount -= (abs((amount + actualGas) - 100));

			if(GetVehicleEngineState(carID))
				ChangeVehicleEngineState(carID, false);	

			SetTimerEx("RefuellingVehicle",(timeFuel * amount), false, "iiii", playerid, carID, amount, gasValue);
			return SendClientMessage(playerid, COLOR_ORANGE, "<!>{FFFFFF}Aguarde enquanto abastecemos seu veículo.");
		}
	}
	return 1;
}

/*
 * M Y
 * C A L L B A C K S
 ******************************************************************************
 */

/**
 * Timer para abastecer todos os veículos.
 * 
 * @param                não possui parâmetros.
 * @return               1 caso verdadeiro.
 */
public TimerLoadVehicleFuel()
{
	LoadVehicleFuel();
	return 1;
}

/**
 * Timer para abastecer o veículo do jogador.
 * 
 * @param playerid       ID do jogador.
 * @param carID          ID do veículo.
 * @param amount         Quantidade de litros.
 * @param gasValue       Valor da gasolina.
 * @return               1 caso verdadeiro.
 */
public RefuellingVehicle(playerid, carID, amount, gasValue)
{

	if(!IsPlayerConnected(playerid))
		return 1;

	SendClientMessageEx(playerid, COLOR_GREEN,"<!>{FFFFFF}Seu veículo foi abastecido com %d litros por $%d.", amount, gasValue);
	carFuel[carID] += amount;
	carMax[carID] = 0;
	GivePlayerMoney(playerid, - gasValue);

	if(!GetVehicleEngineState(carID))
		ChangeVehicleEngineState(carID, true);	

	UpdatePlayerVehicleFuel(playerid);
	return 1;
}

/*
 * FUNCTIONS
 ******************************************************************************
 */


/**
 * Verifica e retira a gasolina levando em conta a quantia de quilômetros rodados e sua velocidade.
 * 
 * @author               KylePT (14/12/2010)
 * @param playerid       ID do jogador.
 * @return               não retorna valores.
 */
static PlayerVehicleFuelCheck(playerid)
{
	if(IsPlayerInAnyVehicle(playerid))
	{
		new carID = GetPlayerVehicleID(playerid);

		GetVehicleVelocity(carID, carVelocity[0], carVelocity[1], carVelocity[2]);

		if(floatround(((floatsqroot(((carVelocity[0] * carVelocity[0]) + (carVelocity[1] * carVelocity[1]) + (carVelocity[2] * carVelocity[2]))) * (170.0))) * 1) > 5)
		{
			if(!carFuel[carID])
			{
				if(GetVehicleEngineState(carID))
					ChangeVehicleEngineState(carID, false);
			}
			else if(carFuel[carID] > 0)
			{
				carMax[carID]++;

				if(carMax[carID] >= (kmMax * 13))
				{
					carFuel[carID]--;
					carMax[carID] = 0;
					UpdatePlayerVehicleFuel(playerid);
				}
			}
		}
	}
}

/**
 * Cria a textdraw global.
 * 
 * @param                não possui parâmetros.
 * @return               não retorna valores.
 */
static CreateGlobalTDVehicleFuel()
{
	textGlobalVehicleFuel[0] = TextDrawCreate(582.000000, 247.000000, "box");
	TextDrawLetterSize(textGlobalVehicleFuel[0], 0.000000, 5.502197);
	TextDrawTextSize(textGlobalVehicleFuel[0], 657.000000, 0.000000);
	TextDrawAlignment(textGlobalVehicleFuel[0], 1);
	TextDrawColor(textGlobalVehicleFuel[0], -1);
	TextDrawUseBox(textGlobalVehicleFuel[0], 1);
	TextDrawBoxColor(textGlobalVehicleFuel[0], 100);
	TextDrawSetShadow(textGlobalVehicleFuel[0], 0);
	TextDrawSetOutline(textGlobalVehicleFuel[0], 0);
	TextDrawBackgroundColor(textGlobalVehicleFuel[0], 255);
	TextDrawFont(textGlobalVehicleFuel[0], 1);
	TextDrawSetProportional(textGlobalVehicleFuel[0], 1);
	
	textGlobalVehicleFuel[1] = TextDrawCreate(574.000000, 236.000000, "");
	TextDrawLetterSize(textGlobalVehicleFuel[1], 0.000000, 0.000000);
	TextDrawTextSize(textGlobalVehicleFuel[1], 70.000000, 70.000000);
	TextDrawAlignment(textGlobalVehicleFuel[1], 1);
	TextDrawColor(textGlobalVehicleFuel[1], -1);
	TextDrawSetShadow(textGlobalVehicleFuel[1], 0);
	TextDrawSetOutline(textGlobalVehicleFuel[1], 0);
	TextDrawBackgroundColor(textGlobalVehicleFuel[1], 0);
	TextDrawFont(textGlobalVehicleFuel[1], 5);
	TextDrawSetProportional(textGlobalVehicleFuel[1], 0);
	TextDrawSetPreviewModel(textGlobalVehicleFuel[1], 1650);
	TextDrawSetPreviewRot(textGlobalVehicleFuel[1], 0.000000, 0.000000, 0.000000, 1.085044);
}

/**
 * Criam as textdraws privadas.
 * 
 * @param playerid       ID do jogador.
 * @return               não retorna valores.
 */
static CreatePrivateTDVehicleFuel(playerid)
{
	textPrivateVehicleFuel[playerid][E_FUEL_BAR] = CreatePlayerTextDraw(playerid, 598.000000, 294.200012, "box");
	PlayerTextDrawLetterSize(playerid, textPrivateVehicleFuel[playerid][E_FUEL_BAR], 0.000000, -4.15);
	PlayerTextDrawTextSize(playerid, textPrivateVehicleFuel[playerid][E_FUEL_BAR], 622.000000, 0.000000);
	PlayerTextDrawAlignment(playerid, textPrivateVehicleFuel[playerid][E_FUEL_BAR], 1);
	PlayerTextDrawColor(playerid, textPrivateVehicleFuel[playerid][E_FUEL_BAR], -1);
	PlayerTextDrawUseBox(playerid, textPrivateVehicleFuel[playerid][E_FUEL_BAR], 1);
	PlayerTextDrawBoxColor(playerid, textPrivateVehicleFuel[playerid][E_FUEL_BAR], -65436);
	PlayerTextDrawSetShadow(playerid, textPrivateVehicleFuel[playerid][E_FUEL_BAR], 0);
	PlayerTextDrawSetOutline(playerid, textPrivateVehicleFuel[playerid][E_FUEL_BAR], 0);
	PlayerTextDrawBackgroundColor(playerid, textPrivateVehicleFuel[playerid][E_FUEL_BAR], 255);
	PlayerTextDrawFont(playerid, textPrivateVehicleFuel[playerid][E_FUEL_BAR], 1);
	PlayerTextDrawSetProportional(playerid, textPrivateVehicleFuel[playerid][E_FUEL_BAR], 1);
	
	textPrivateVehicleFuel[playerid][E_FUEL_PERCENT] = CreatePlayerTextDraw(playerid, 610.000000, 266.000000, "12%");
	PlayerTextDrawLetterSize(playerid, textPrivateVehicleFuel[playerid][E_FUEL_PERCENT], 0.243982, 1.419167);
	PlayerTextDrawAlignment(playerid, textPrivateVehicleFuel[playerid][E_FUEL_PERCENT], 2);
	PlayerTextDrawColor(playerid, textPrivateVehicleFuel[playerid][E_FUEL_PERCENT], -1);
	PlayerTextDrawSetShadow(playerid, textPrivateVehicleFuel[playerid][E_FUEL_PERCENT], 0);
	PlayerTextDrawSetOutline(playerid, textPrivateVehicleFuel[playerid][E_FUEL_PERCENT], 0);
	PlayerTextDrawBackgroundColor(playerid, textPrivateVehicleFuel[playerid][E_FUEL_PERCENT], 255);
	PlayerTextDrawFont(playerid, textPrivateVehicleFuel[playerid][E_FUEL_PERCENT], 2);
	PlayerTextDrawSetProportional(playerid, textPrivateVehicleFuel[playerid][E_FUEL_PERCENT], 1);
}

/**
 * Exibe a textdraw de gasolina.
 * 
 * @param playerid       ID do jogador.
 * @return               não retorna valores.
 */
static ShowPlayerVehicleFuel(playerid)
{
	TextDrawShowForPlayer(playerid, textGlobalVehicleFuel[0]);
	TextDrawShowForPlayer(playerid, textGlobalVehicleFuel[1]);
	UpdatePlayerVehicleFuel(playerid);

	playerViewingVehicleFuel[playerid] = true;
}

/**
 * Esconde a textdraw de gasolina.
 * 
 * @param playerid       ID do jogador.
 * @return               não retorna valores.
 */
static HidePlayerVehicleFuel(playerid)
{
	TextDrawHideForPlayer(playerid, textGlobalVehicleFuel[0]);
	TextDrawHideForPlayer(playerid, textGlobalVehicleFuel[1]);
	PlayerTextDrawHide(playerid, textPrivateVehicleFuel[playerid][E_FUEL_BAR]);	
	PlayerTextDrawHide(playerid, textPrivateVehicleFuel[playerid][E_FUEL_PERCENT]);

	playerViewingVehicleFuel[playerid] = false;
}

/**
 * Atualiza a textdraw de gasolina.
 * 
 * @param playerid       ID do jogador.
 * @return               não retorna valores.
 */
static UpdatePlayerVehicleFuel(playerid)
{
    if(!IsPlayerInAnyVehicle(playerid))
        return;

    new 
    	vehicleid = GetPlayerVehicleID(playerid),
    	fuel = carFuel[vehicleid],
        Float:progressBar;

    PlayerTextDrawSetStringFormat(playerid, textPrivateVehicleFuel[playerid][E_FUEL_PERCENT], "%dL", fuel);

    progressBar = -((4.15 * _:fuel) / 100.0);

    PlayerTextDrawLetterSize(playerid, textPrivateVehicleFuel[playerid][E_FUEL_BAR], 0.0, progressBar);
    
    PlayerTextDrawShow(playerid, textPrivateVehicleFuel[playerid][E_FUEL_PERCENT]);
    PlayerTextDrawShow(playerid, textPrivateVehicleFuel[playerid][E_FUEL_BAR]);
}

/**
 * Verifica se a textdraw está sendo exibida para o jogador.
 * 
 * @param playerid       ID do jogador.
 * @return               retorna se o jogador está visualizando ou não.
 */
static IsPlayerViewingVehicleFuel(playerid)
	return playerViewingVehicleFuel[playerid];


/**
 * Faz as verificações necessárias para poder abastecer um veículo.
 * 
 * @param playerid           ID do jogador.
 * @param bool:showMessage   Envia a mensagem caso verdadeiro.
 * @return                   não retorna valores.
 */
static PlayerFuelVehicle(playerid, bool:showMessage)
{
	if(!IsPlayerInAnyVehicle(playerid))
	{
		if(showMessage)
			SendClientMessage(playerid, COLOR_RED, "<!>{FFFFFF}Você não está em um veículo.");

		return;
	}

	else if(GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
	{
		if(showMessage)
			SendClientMessage(playerid, COLOR_RED, "<!>{FFFFFF}Você não está dirigindo um veículo.");

		return;
	}

	for(new i; i < gasStationsMax; i++)
	{
		if(IsPlayerInRangeOfPoint(playerid, 3.0, gasStations[i][E_GAS_STATION_POS_X], gasStations[i][E_GAS_STATION_POS_Y], gasStations[i][E_GAS_STATION_POS_Z]))
		{    
			playerinGasStation[playerid] = i;    
			ShowFuelPanel(playerid);
			break;
		}
	}
}

/**
 * Exibe a caixa de diálogo de abastecimento do veículo.
 * 
 * @param playerid           ID do jogador.
 * @param bool:showMessage   Envia a mensagem caso verdadeiro.
 * @return                   não retorna valores.
 */
static ShowFuelPanel(playerid)
{
	new
		gasID = playerinGasStation[playerid],
		caption[(20 + 26) + 1],
		info[(91 + 4) + 1];

	format(caption, sizeof(caption), "Posto de Gasolina %s", gasStations[gasID][E_GAS_STATION_NAME]);
	format(info, sizeof(info), "O valor do litro da gasolina no posto é de %d\ndeseja abastecer seu veículo com quantos litros?", gasStations[gasID][E_GAS_STATION_VALUE]);

	ShowPlayerDialog(playerid, DIALOG_GAS_TO_FUEL, DIALOG_STYLE_INPUT, caption, info, "Abastecer", "Cancelar");
}

/**
 * Exibe a caixa de diálogo dos postos de gasolina.
 * 
 * @param playerid           ID do jogador.
 * @return                   não retorna valores.
 */
static ShowPricePanel(playerid)
{
	new 
		info[41 + (gasStationsMax * (8 + 26 + 6 + 7 + 24)) + 1],
		i, listCount;

	info = "Localização\tLitro da Gasolina";

	for(i = 0; i < gasStationsMax; i++)
	{
		format(info, sizeof(info), "%s\n{ffff99}%s\t{39ac39}$%d", info, gasStations[i][E_GAS_STATION_NAME], gasStations[i][E_GAS_STATION_VALUE]);

		adminGasStationsList[playerid][listCount] = i;
		listCount++;
	}

	ShowPlayerDialog(playerid, DIALOG_GAS_PRICE_LIST, DIALOG_STYLE_TABLIST_HEADERS, "Controle do valor da Gasolina.", info, "Alterar", "Sair");
}

/**
 * Organiza a lista dos postos de gasolina em ordem crescente de distância.
 * Exibe um dialog com a lista dos postos, localização e valor do litro.
 * 
 * @param playerid           ID do jogador.
 * @return                   não retorna valores.
 */
static ShowStationPanel(playerid)
{
	new smallerPosIndex,
		Float:smallerPos = 8000.0,
		Float:stationPos[gasStationsMax],
		bool:isInList[gasStationsMax],
		stationList[gasStationsMax],
		listCount,
		info[41 + (gasStationsMax * (8 + 26 + 6 + 7 + 24)) + 1],
		size, i;

	size = gasStationsMax;
	smallerPosIndex = -1;

	for(i = 0; i < size; i++)
	{
		stationPos[i] = GetPlayerDistanceFromPoint(playerid, gasStations[i][E_GAS_STATION_POS_X], gasStations[i][E_GAS_STATION_POS_Y], gasStations[i][E_GAS_STATION_POS_Z]);
		stationList[i] = -1;
	}

	for(i = 0; i < size; i++)
	{
		if(!isInList[i] && stationPos[i] < smallerPos)
		{
			smallerPos = stationPos[i];
			smallerPosIndex = i;
		}

		if(i == (size - 1))
		{
			if(!~smallerPosIndex)
				break;

			if(listCount == size)
				break;

			isInList[smallerPosIndex] = true;
			stationList[listCount] = smallerPosIndex;
			smallerPos = 8000.0;
			smallerPosIndex = -1;
			listCount++;
			i = -1;
		}
	}

	info = "Localização\tLitro da gasolina\tDistância";
	listCount = 0;

	for(i = 0; i < size; i++)
	{
		if(!~stationList[i])
			continue;

		smallerPos = GetPlayerDistanceFromPoint(playerid, gasStations[stationList[i]][E_GAS_STATION_POS_X], gasStations[stationList[i]][E_GAS_STATION_POS_Y], gasStations[stationList[i]][E_GAS_STATION_POS_Z]);
		
		format(info, sizeof(info), "%s\n{ffff99}%s\t{39ac39}$%d\t{ac3939}%.2fm", info, gasStations[stationList[i]][E_GAS_STATION_NAME], gasStations[stationList[i]][E_GAS_STATION_VALUE], smallerPos);

		playerGasStationsList[playerid][listCount] = stationList[i];
		listCount++;
	}

	ShowPlayerDialog(playerid, DIALOG_GAS_STATION_LIST, DIALOG_STYLE_TABLIST_HEADERS, "Postos de Gasolina", info, "Rota", "Sair");
}

/**
 * Carrega as 3DTextLabels dos postos de gasolina.
 * 
 * @param gasStationID       ID do posto de gasolina.
 * @return                   não retorna valores.
 */
static LoadGasStation(gasStationID = -1)
{
	new info[72 + 26];

	if(!~gasStationID)
	{
		for(new i; i < gasStationsMax; i++)
		{
			format(info, sizeof(info), "Posto de Gasolina %s\nValor da gasolina: $%d/L\nPressione 'H' para abastecer.", gasStations[i][E_GAS_STATION_NAME], gasStations[i][E_GAS_STATION_VALUE]);
			gasStations3DText[i] = Create3DTextLabel(info, COLOR_GREEN, gasStations[i][E_GAS_STATION_POS_X], gasStations[i][E_GAS_STATION_POS_Y], gasStations[i][E_GAS_STATION_POS_Z], 20, 0, 0);
		}
		return;
	}

	format(info, sizeof(info), "Posto de Gasolina %s\nValor da gasolina: $%d/L\nPressione 'H' para abastecer.", gasStations[gasStationID][E_GAS_STATION_NAME], gasStations[gasStationID][E_GAS_STATION_VALUE]);
	Update3DTextLabelText(gasStations3DText[gasStationID], COLOR_GREEN, info);
}

/**
 * Abastece os veículos com uma quantia aleatória de valor.
 * 
 * @param vehicleid          ID do veículo.
 * @return                   não retorna valores.
 */
static LoadVehicleFuel(vehicleid = INVALID_VEHICLE_ID)
{
	if(vehicleid == INVALID_VEHICLE_ID)
	{

		for(new i = 1, vehicles = GetVehiclePoolSize(); i <= vehicles; i++)
			LoadVehicleFuel(i);

		return;
	}

	new
		engine, lights, alarm, doors, bonnet, boot, objective;

	GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
	SetVehicleParamsEx(vehicleid, VEHICLE_PARAMS_ON, lights, alarm, doors, bonnet, boot, objective);	

	carFuel[vehicleid] = 50 + random(50);
}

/*
 * C O R R E C T I O N S
 ******************************************************************************
 */

/**
 * Correção para a função funcionar junto ao sistema.
 */
stock gasSystem_CreateVehicle(vehicletype, Float:x, Float:y, Float:z, Float:rotation, color1, color2, respawn_delay, addsiren=0)
{
	new vehicleid = CreateVehicle(vehicletype, x, y, z, rotation, color1, color2, respawn_delay, addsiren);
	LoadVehicleFuel(vehicleid);
	return vehicleid;
}

/**
 * Correção para a função funcionar junto ao sistema.
 */
stock gasSystem_AddStaticVehicleEx(modelid, Float:spawn_x, Float:spawn_y, Float:spawn_z, Float:z_angle, color1, color2, respawn_delay, addsiren=0)
{
	new vehicleid = AddStaticVehicleEx(modelid, spawn_x, spawn_y, spawn_z, z_angle, color1, color2, respawn_delay, addsiren);	
	LoadVehicleFuel(vehicleid);
	return vehicleid;
}

/**
 * Correção para a função funcionar junto ao sistema.
 */
stock gasSystem_AddStaticVehicle(modelid, Float:spawn_x, Float:spawn_y, Float:spawn_z, Float:z_angle, color1, color2)
{
	new vehicleid = AddStaticVehicle(modelid, spawn_x, spawn_y, spawn_z, z_angle, color1, color2);
	LoadVehicleFuel(vehicleid);
	return vehicleid;
}

/*
 * C O M P L E M E N T S
 ******************************************************************************
 */


/**
 * Printa no Console o aviso do sistema carregado.
 * 
 * @param systemName[]       nome do sistema.
 * @return                   não retorna valores.
 */
static PrintSystemLoaded(systemName[])
{
	new splitter[100], size, i;

	size = ((strlen(systemName) < 13) ? (13) : (strlen(systemName)));

	for(i = 0; i < size; i++)
		splitter[i] = '-';

	format(splitter, sizeof(splitter), "%s------", splitter);

	printf("\n---------------%s", splitter);
	printf("      > %s loaded", systemName);
	print("      > Developed by Vithinn");
	printf("---------------%s\n", splitter);
}

/**
 * Função responsável pelo textdraw fix.
 * 
 * @param                    não possui parâmetros.
 * @return                   não retorna valores.
 */
static FixCreateTextDrawTransparency()
{
    textBugFix = TextDrawCreate(0.0, 0.0, "fix");
    TextDrawLetterSize(textBugFix, 0.000000, 0.000000);
}

/**
 * Exibe para um jogador o TextdrawFix
 * 
 * @param playerid           ID do jogador.
 * @return                   não retorna valores.
 */
static FixShowTextDrawTransparency(playerid)
    TextDrawShowForPlayer(playerid, textBugFix);

/**
 * Transforma o valor em absoluto.
 * 
 * @param int                valor.
 * @return                   retorna o valor positivo.
 */
static abs(int)
    return ((int < 0) ? (-int) : (int));

/**
 * Reseta as variáveis de um jogador.
 * 
 * @param playerid           ID do jogador.
 * @return                   não retorna valores.
 */
static ResetPlayerVariables(playerid)
{
	for(new i; i < gasStationsMax; i++)
	{
		playerGasStationsList[playerid][i] = -1;
		adminGasStationsList[playerid][i] = -1;
		playerinGasStation[playerid] = -1;
	}

	playerViewingVehicleFuel[playerid] = false;
}

/**
 * Recebe o estado do motor do veículo.
 * 
 * @param vehicleid          ID do veículo.
 * @return                   retorna caso o veículo esteja com o motor ligado.
 */
static GetVehicleEngineState(vehicleid)
{
	if(!IsValidVehicle(vehicleid))
		return false;

	static engine, lights, alarm, doors, bonnet, boot, objective;
	GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
	return (engine == VEHICLE_PARAMS_ON);
}

/**
 * Altera o estado do motor do veículo.
 * 
 * @param vehicleid          ID do veículo.
 * @param bool:value         true para ligar o motor, false para desligar.
 * @return                   não retorna valores.
 */
static ChangeVehicleEngineState(vehicleid, bool:value)
{
	if(!IsValidVehicle(vehicleid))
		return;

	static engine, lights, alarm, doors, bonnet, boot, objective;
	GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
	SetVehicleParamsEx(vehicleid, ((value) ? (VEHICLE_PARAMS_ON) : (VEHICLE_PARAMS_OFF)), lights, alarm, doors, bonnet, boot, objective);
}

/*
 * C O M M A N D S
 ******************************************************************************
 */

/**
 * Comando para abrir a caixa de diálogo com os postos de gasolina.
 * 
 * @param playerid           ID do jogador.
 * @return                   retorna caso a ação tenha sido efetuada com sucesso.
 */
CMD:postos(playerid)
{
	if(!IsPlayerInAnyVehicle(playerid))
		return SendClientMessage(playerid, COLOR_RED, "<!>{FFFFFF}Você não está em um veículo.");

	else if(GetPlayerState(playerid) != PLAYER_STATE_DRIVER)
		return SendClientMessage(playerid, COLOR_RED, "<!>{FFFFFF}Você não está dirigindo um veículo.");

	ShowStationPanel(playerid);
	return 1;
}

/**
 * Comando para abrir a caixa de alteração de valores dos postos de gasolina.
 * 
 * @param playerid           ID do jogador.
 * @return                   retorna caso a ação tenha sido efetuada com sucesso.
 */
CMD:preco(playerid)
{
	if(!IsPlayerAdmin(playerid))
		return SendClientMessage(playerid, COLOR_RED, "<!>{FFFFFF}Você não é um administrador");

	ShowPricePanel(playerid);
	return 1;
}

/**
 * Comando para abrir a caixa de diálogo de abastecimento.
 * 
 * @param playerid           ID do jogador.
 * @return                   retorna caso a ação tenha sido efetuada com sucesso.
 */
CMD:abastecer(playerid)
{
	PlayerFuelVehicle(playerid, true);
	return 1;
}

/*
 * H O O K S
 ******************************************************************************
 */


/**
 * Hook da função CreateVehicle
 */
#if defined _ALS_CreateVehicle
	#undef CreateVehicle
#else
	#define _ALS_CreateVehicle
#endif
#define CreateVehicle gasSystem_CreateVehicle

/**
 * Hook da função AddStaticVehicleEx
 */
#if defined _ALS_AddStaticVehicleEx
	#undef AddStaticVehicleEx
#else
	#define _ALS_AddStaticVehicleEx
#endif
#define AddStaticVehicleEx gasSystem_AddStaticVehicleEx

/**
 * Hook da função AddStaticVehicle
 */
#if defined _ALS_AddStaticVehicle
	#undef AddStaticVehicle
#else
	#define _ALS_AddStaticVehicle
#endif
#define AddStaticVehicle gasSystem_AddStaticVehicle