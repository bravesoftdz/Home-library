unit Unit2;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, OleCtrls, SHDocVw, MSHTML, ShellAPI, StdCtrls, XPMan;

type
  TDescriptionForm = class(TForm)
    WebView: TWebBrowser;
    XPManifest: TXPManifest;
    procedure WebViewDocumentComplete(Sender: TObject;
      const pDisp: IDispatch; var URL: OleVariant);
    procedure FormShow(Sender: TObject);
    procedure WebViewBeforeNavigate2(Sender: TObject;
      const pDisp: IDispatch; var URL, Flags, TargetFrameName, PostData,
      Headers: OleVariant; var Cancel: WordBool);
  private
    procedure NFOParse(FileName: string);
    { Private declarations }
  public
    { Public declarations }
  end;

var
  DescriptionForm: TDescriptionForm;

implementation

uses Unit1;

{$R *.dfm}

{function ExtractYear(Str: string): string; //������� ���
begin
  Result:='';
  Str:=Trim(Str);
  if (Str[Length(Str)]=')') and (Str[Length(Str) - 5] = '(') then begin
    Delete(Str, 1, Length(Str) - 5);
    Delete(Str, Length(Str), 1);
    Result:=Str;
  end;
end;

function ExtractWithoutYear(Str: string): string; //������� ���
begin
  Result:=Str;
  Str:=Trim(Str);
  if (Str[Length(Str)] = ')') and (Str[Length(Str) - 5] = '(') then begin
    Delete(Str, Length(Str) - 5, 6);
    Result:=Trim(Str);
  end;
end;}

procedure TDescriptionForm.WebViewDocumentComplete(Sender: TObject;
  const pDisp: IDispatch; var URL: OleVariant);
var
  CoverImage, NFOFilePath: string;
  SearchResult: TSearchRec;
begin
  if pDisp=(Sender as TWebBrowser).Application then
    if ExtractFileName(StringReplace(URL, '/', '\', [rfReplaceAll])) = 'description.html' then begin
      WebView.Visible:=true;

      if FileExists(CurDir + '\cover.jpg') then CoverImage:=CurDir + '\cover.jpg';
      if CoverImage = '' then
        if FileExists(CurDir + '\cover.png') then CoverImage:=CurDir + '\cover.png';
      if CoverImage = '' then
        if FileExists(CurDir + '\cover.gif') then CoverImage:=CurDir + '\cover.gif';
      if CoverImage = '' then
        if FileExists(CurDir + '\cover.jpeg') then CoverImage:=CurDir + '\cover.jpeg';

      WebView.OleObject.Document.getElementById('header').innerHTML:='<h1>' + CurItem + '</h1>';
      WebView.OleObject.Document.getElementById('links').innerHTML:='';
      WebView.OleObject.Document.getElementById('cover').innerHTML:='<img src="' + CoverImage + '" />';
      WebView.OleObject.Document.getElementById('description').innerHTML:='<a href="#create">+</a>';

      NFOFilePath:='';
      //����� NFO �����
      if FindFirst(CurDir + '\*.nfo', faAnyFile, SearchResult) = 0 then begin
          NFOFilePath:=CurDir + '\' + SearchResult.Name;
        FindClose(SearchResult);
      end;

      //������ ���������� ��� ��� (���������������)
      if FindFirst(CurDir + '\*.exe', faAnyFile, SearchResult) = 0 then begin
        repeat
          if SearchResult.Attr <> faDirectory then begin
            if Pos('setup', AnsiLowerCase(SearchResult.Name)) > 0 then begin
              WebView.OleObject.Document.getElementById('links').innerHTML:=WebView.OleObject.Document.getElementById('links').innerHTML +
              '<a href="#open=' + StringReplace(CurDir, ' ', '%20', [rfReplaceAll]) + '\' + SearchResult.Name + '">' + IDC_INSTALL + '</a>';
              Break;
            end;       end;
        until FindNext(SearchResult) <> 0;
        FindClose(SearchResult);
      end;

      //������� � ����������� ������
      if NFOFilePath <> '' then
        NFOParse(NFOFilePath);

      //������ ������� ����� ��� ���� ���������
      WebView.OleObject.Document.getElementById('links').innerHTML:=WebView.OleObject.Document.getElementById('links').innerHTML +
      '<a href="#folder">' + IDC_FOLDER + '</a>';

      if WebView.Document <> nil then
        (WebView.Document as IHTMLDocument2).ParentWindow.Focus;
    end;
end;

function ParseList(OnSet, OutSet, HTMLSource: string): string;
begin
  while (Pos(OnSet, HTMLSource) > 0) or (Pos(OutSet, HTMLSource) > 0) do begin
    if Result = '' then
      Result:=Copy(HTMLSource, Pos(OnSet, HTMLSource) + Length(OnSet), Pos(OutSet, HTMLSource) - Pos(OnSet, HTMLSource) - Length(OnSet)) else
    Result:=Result + ', ' + Copy(HTMLSource, Pos(OnSet, HTMLSource) + Length(OnSet), Pos(OutSet, HTMLSource) - Pos(OnSet, HTMLSource) - Length(OnSet));
    Delete(HTMLSource, 1, Pos(OutSet, HTMLSource) + Length(OutSet) - 1);
  end;
end;

function ParseTag(TagName, HTMLSource: string): string;
begin
  if Pos(TagName, HTMLSource) > 0 then begin
    Delete(HTMLSource, 1, Pos(TagName, HTMLSource) + Length(TagName) - 1);
    Result:=Copy(HTMLSource, 1, Pos('</' + Copy(TagName, 2, Length(TagName) - 2), HTMLSource) - 1);
  end else
    Result:='';
end;

procedure TDescriptionForm.NFOParse(FileName: string);
var
  NFOFile: TStringList; Content, Title, OriginalTitle, Description, Year, Country, Studio, Director, Credits, Publisher, Author, Developer, Genre, Premiered, Runtime, Actors: string;
  Hour, Minutes, FullTime: Integer;
  NFOType: (MovieNFO, TVShowNFO, GameNFO, BookNFO);
  CustomButtons: string;
const
  ItemNameStart = '<div id="item"><div id="title">';
  ItemNameEnd = '</div>';
  ValueNameStart = '<div id="value">';
  ValueNameEnd = '</div></div>';
begin
  NFOFile:=TStringList.Create;
  NFOFile.LoadFromFile(FileName);
  NFOFile.Text:=UTF8ToAnsi(NFOFile.Text);

  Content:='';

  //����������� ���� NFO
  if (Pos('<movie>', NFOFile.Text) > 0) then
    NFOType:=MovieNFO
  else if (Pos('<tvshow>', NFOFile.Text) > 0) then
    NFOType:=TVShowNFO
  else if (Pos('<game>', NFOFile.Text) > 0) then
    NFOType:=GameNFO
  else if (Pos('<book>', NFOFile.Text) > 0) then
    NFOType:=BookNFO;

  //���������
  Title:=ParseTag('<title>', NFOFile.Text);
  OriginalTitle:=ParseTag('<originaltitle>', NFOFile.Text);

  //� �������� ���������� ��� ������� ���������
  if NFOType = TVShowNFO then
    OriginalTitle:=ParseTag('<showtitle>', NFOFile.Text);

  //������� ���������
  WebView.OleObject.Document.getElementById('header').innerHTML:='<h1>' + Title + '</h1>';
  if (OriginalTitle <> '') and (Title <> OriginalTitle) then
    WebView.OleObject.Document.getElementById('header').innerHTML:=WebView.OleObject.Document.getElementById('header').innerHTML +
    '<h2>' + OriginalTitle + '</h2>';

  //������ NFO

  //���
  if (NFOType = MovieNFO) or (NFOType = TVShowNFO) then begin
    Year:=ParseTag('<year>', NFOFile.Text);
    if Year <> '' then
      Content:=Content + ItemNameStart + IDS_YEAR + ItemNameEnd + ValueNameStart + Year + ValueNameEnd;
  end;

  //������
  Country:=ParseList('<country>', '</country>', NFOFile.Text);
    if Country <> '' then
      Content:=Content + ItemNameStart + IDS_COUNTRY + ItemNameEnd + ValueNameStart + Country + ValueNameEnd;

  if (NFOType = MovieNFO) or (NFOType = TVShowNFO) then begin
    //������
    Studio:=ParseList('<studio>', '</studio>', NFOFile.Text);
    if Director <> '' then
      Content:=Content + ItemNameStart + IDS_STUDIO + ItemNameEnd + ValueNameStart + Studio + ValueNameEnd;

    //�������
    Director:=ParseList('<director>', '</director>', NFOFile.Text);
    if Director <> '' then
      Content:=Content + ItemNameStart + IDS_DIRECTOR + ItemNameEnd + ValueNameStart + Director + ValueNameEnd;

    //���������
    Credits:=ParseList('<credits>', '</credits>', NFOFile.Text);
    if Credits <> '' then
      Content:=Content + ItemNameStart + IDS_CREDITS + ItemNameEnd + ValueNameStart + Credits + ValueNameEnd;

  end;

  if (NFOType = GameNFO) or (NFOType = BookNFO) then begin
    //��������
    Publisher:=ParseList('<publisher>', '</publisher>', NFOFile.Text);
    if Publisher <> '' then
      Content:=Content + ItemNameStart + IDS_PUBLISHER + ItemNameEnd + ValueNameStart + Publisher + ValueNameEnd;
  end;

  if NFOType = GameNFO then begin
    //�����������
    Developer:=ParseList('<developer>', '</developer>', NFOFile.Text);
    if Developer <> '' then
	    Content:=Content + ItemNameStart + IDS_DEVELOPER + ItemNameEnd + ValueNameStart + Developer + ValueNameEnd;
  end;

  if NFOType = BookNFO then begin
    //�����
    Author:=ParseList('<author>', '</author>', NFOFile.Text);
    if Publisher <> '' then
      Content:=Content + ItemNameStart + IDS_AUTHOR + ItemNameEnd + ValueNameStart + Author + ValueNameEnd;
  end;

  //�����
  Genre:=ParseList('<genre>', '</genre>', NFOFile.Text);
  if Genre <> '' then
    Content:=Content + ItemNameStart + IDS_GENRE + ItemNameEnd + ValueNameStart + Genre + ValueNameEnd;

  //��������
  Premiered:=ParseTag('<premiered>', NFOFile.Text);
  if Premiered <> '' then
    Content:=Content + ItemNameStart + IDS_PREMIERED + ItemNameEnd + ValueNameStart + Premiered + ValueNameEnd;

  if (NFOType = MovieNFO) or (NFOType = TVShowNFO) then begin
    //�����
    Runtime:=ParseTag('<runtime>', NFOFile.Text);
    if Runtime <> '' then begin

      FullTime:=StrToIntDef(Runtime, 0);
      Content:=Content + ItemNameStart + IDS_RUNTIME + ItemNameEnd + ValueNameStart + Runtime + ' ���. (' + Format('%.2d:%.2d:00', [FullTime div 60, FullTime - (FullTime div 60) * 60]) + ')' + ValueNameEnd;
    end;
  end;

  {if (NFOType = MovieNFO) or (NFOType = TVShowNFO) then begin
  //� ������� �����:
    Actors:=ParseList('<name>', '</name>', ParseList('<actor>', '</actor>', NFOFile.Text));
    if Actors <> '' then
      Content:=Content + ItemNameStart + '� ������� �����' + ItemNameEnd + '<div>' + Actors + ValueNameEnd;
  end;}

  //������ ��� MovieNFO
  if NFOType = MovieNFO then
    WebView.OleObject.Document.getElementById('links').innerHTML:='<a href="#movie">' + IDC_VIEW + '</a>';

  //������ ��� BookNFO
  if NFOType = BookNFO then
    WebView.OleObject.Document.getElementById('links').innerHTML:='<a href="#book">' + IDC_OPEN + '</a>';

  //��������� ������
  if (Pos('<buttons>', NFOFile.Text) > 0) then
    CustomButtons:=ParseTag('<buttons>', NFOFile.Text);
  if CustomButtons <> '' then begin
    CustomButtons:=Trim(CustomButtons);
    CustomButtons:=StringReplace(CustomButtons, 'button open', 'button-open', [rfReplaceAll]);
    CustomButtons:=StringReplace(CustomButtons, ' ', '%20', [rfReplaceAll]);
    CustomButtons:=StringReplace(CustomButtons, '<button-open="', '<a href="#open=' + CurDir + '\', [rfReplaceAll]);
    CustomButtons:=StringReplace(CustomButtons, '</button>', '</a>', [rfReplaceAll]);
    WebView.OleObject.Document.getElementById('links').innerHTML:=
    WebView.OleObject.Document.getElementById('links').innerHTML + CustomButtons;
  end;

  //��������
  Description:=ParseTag('<plot>', NFOFile.Text);
  if Description <> '' then
    Content:=Content + '<br>' + Description;

  //�����
  WebView.OleObject.Document.getElementById('description').innerHTML:=Content;

  NFOFile.Free;
end;

procedure TDescriptionForm.FormShow(Sender: TObject);
begin
  DescriptionForm.Caption:=IDS_TITLE + ': ' + CurItem;
  WebView.Navigate(ExtractFilePath(ParamStr(0)) + StyleName + 'description.html');
end;

procedure TDescriptionForm.WebViewBeforeNavigate2(Sender: TObject;
  const pDisp: IDispatch; var URL, Flags, TargetFrameName, PostData,
  Headers: OleVariant; var Cancel: WordBool);
var
  sUrl, sValue: string;
  SearchResult: TSearchRec;
begin
  sUrl:=Copy(URL, Pos('description.html', URL), Length(URL) - Pos('description.html', URL) + 1);

  if Pos('description.html', sUrl) = 0 then Cancel:=true;

  if sUrl = 'description.html#movie' then
    if FindFirst(CurDir + '\*.*', faAnyFile, SearchResult) = 0 then begin
      repeat
        if SearchResult.Attr <> faDirectory then
          if (AnsiLowerCase(ExtractFileExt(SearchResult.Name)) = '.avi') or
          (AnsiLowerCase(ExtractFileExt(SearchResult.Name)) = '.mp4') or
          (AnsiLowerCase(ExtractFileExt(SearchResult.Name)) = '.mpeg') or
          (AnsiLowerCase(ExtractFileExt(SearchResult.Name)) = '.mkv') or
          (AnsiLowerCase(ExtractFileExt(SearchResult.Name)) = '.mov') then begin
            ShellExecute(Handle, 'open', PChar(CurDir + '\' + SearchResult.Name), nil, nil, SW_SHOW);
            Break;
          end;
      until FindNext(SearchResult) <> 0;
      FindClose(SearchResult);
    end;


  if sUrl = 'description.html#book' then
    if FindFirst(CurDir + '\*.*', faAnyFile, SearchResult) = 0 then begin
      repeat
        if (SearchResult.Name <> '.') and (SearchResult.Name <> '..') and (SearchResult.Attr <> faDirectory) then
          if (AnsiLowerCase(ExtractFileExt(SearchResult.Name)) = '.pdf') or
          (AnsiLowerCase(ExtractFileExt(SearchResult.Name)) = '.epub') or
          (AnsiLowerCase(ExtractFileExt(SearchResult.Name)) = '.txt') or
          (AnsiLowerCase(ExtractFileExt(SearchResult.Name)) = '.djvu') or
          (AnsiLowerCase(ExtractFileExt(SearchResult.Name)) = '.fb2') or
          (AnsiLowerCase(ExtractFileExt(SearchResult.Name)) = '.rtf') or
          (AnsiLowerCase(ExtractFileExt(SearchResult.Name)) = '.doc') or
          (AnsiLowerCase(ExtractFileExt(SearchResult.Name)) = '.docx') or
          (AnsiLowerCase(ExtractFileExt(SearchResult.Name)) = '.mobi') then begin
            ShellExecute(Handle, 'open', PChar(CurDir + '\' + SearchResult.Name), nil, nil, SW_SHOW);
            Break;
          end;
      until FindNext(SearchResult) <> 0;
      FindClose(SearchResult);
    end;

  if Pos('description.html#open=', sUrl) > 0 then begin
    Delete(sUrl, 1, Pos('#open=', sUrl) + 5);
    sUrl:=StringReplace(sUrl, '%20', ' ', [rfReplaceAll]);
    ShellExecute(Handle, 'open', PChar(sUrl), nil, nil, SW_SHOW);
  end;

  if sUrl = 'description.html#folder' then
    ShellExecute(Handle, 'open', PChar(CurDir), nil, nil, SW_SHOW);

  if sUrl = 'description.html#create' then
    with CreateMessageDialog(PChar(IDS_CHOOSE_MEDIA_TYPE), mtConfirmation, [mbOK, mbYes, mbNo, mbAll, mbCancel]) do
    try
      TButton(FindComponent('Yes')).Caption:=IDC_MOVIE;
      TButton(FindComponent('OK')).Caption:=IDC_GAME;
      TButton(FindComponent('No')).Caption:=IDC_TVSHOW;
      TButton(FindComponent('Cancel')).Caption:=IDC_BOOK;
      TButton(FindComponent('All')).Caption:=IDC_CANCEL;
      case ShowModal of
        mrYes:
          begin
            CopyFile(PChar(ExtractFilePath(ParamStr(0)) + 'nfo\movie.nfo'), PChar(CurDir + '\movie.nfo'), true);
            ShellExecute(Handle, 'open', PChar(GetEnvironmentVariable('systemroot')  + '\system32\notepad.exe'), PChar(CurDir + '\movie.nfo'), nil, SW_SHOW);
          end;
        mrNo:
          begin
            CopyFile(PChar(ExtractFilePath(ParamStr(0)) + 'nfo\tvshow.nfo'), PChar(CurDir + '\tvshow.nfo'), true);
            ShellExecute(Handle, 'open', PChar(GetEnvironmentVariable('systemroot')  + '\system32\notepad.exe'), PChar(CurDir + '\tvshow.nfo'), nil, SW_SHOW);
          end;
        mrOK:
          begin
            CopyFile(PChar(ExtractFilePath(ParamStr(0)) + 'nfo\game.nfo'), PChar(CurDir + '\game.nfo'), true);
            ShellExecute(Handle, 'open', PChar(GetEnvironmentVariable('systemroot')  + '\system32\notepad.exe'), PChar(CurDir + '\game.nfo'), nil, SW_SHOW);
          end;
        mrCancel:
          begin
            CopyFile(PChar(ExtractFilePath(ParamStr(0)) + 'nfo\book.nfo'), PChar(CurDir + '\book.nfo'), true);
            ShellExecute(Handle, 'open', PChar(GetEnvironmentVariable('systemroot')  + '\system32\notepad.exe'), PChar(CurDir + '\book.nfo'), nil, SW_SHOW);
          end;
      end;
    finally
      Free;
    end;
end;

end.